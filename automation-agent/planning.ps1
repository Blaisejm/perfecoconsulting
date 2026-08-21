<#
.SYNOPSIS
    Registre central des publications PerfEco : ce qui est prévu, quand exactement,
    et où en est sa préparation.

.DESCRIPTION
    Demande de Jean-Michel, 21/08/2026 :
      « Il faut absolument que l'ensemble des routines de publication passent par un
        fichier centralisé qui leur rappelle ce qui est prévu et à quel moment (date
        précise) ainsi que son niveau de préparation ou de réalisation. […] il y a trop
        de routines Claude Work et Claude Code qui agissent de manière indépendante. »

    Le fichier est `automation-agent/publications.json`.

    POINT D'ARCHITECTURE — pourquoi ce registre ne dérive pas :
    le `statut` des échéances à venir n'est jamais saisi à la main. `-Rafraichir` le
    RECALCULE en lisant les vraies files d'attente (automation-queue/*.json) : présence
    du fichier, `date_prevue`, et surtout `social_post.message` non vide — le champ que
    lit réellement le workflow de publication. Le registre est un cache vérifié, pas une
    seconde saisie.

.PARAMETER Rafraichir
    Recalcule le statut de chaque échéance à venir depuis les fichiers réels, et écrit.

.PARAMETER Ajouter
    Enregistre une publication (utiliser aussi pour les publications MANUELLES, hors
    pipeline : c'est leur absence du registre qui a causé la collision du 21/08).

.PARAMETER Jours
    Fenêtre d'affichage à venir. Défaut : 21 jours.

.EXAMPLE
    .\planning.ps1                      # le planning
    .\planning.ps1 -Rafraichir          # recalcule les statuts puis affiche
    .\planning.ps1 -Tout                # inclut l'historique publié
    .\planning.ps1 -Ajouter -Date 2026-08-24 -Format ad-hoc -Sujet "..." -Statut publie_hors_pipeline
#>

[CmdletBinding()]
param(
    [switch] $Rafraichir,
    [switch] $Tout,
    [int]    $Jours = 21,

    [switch] $Ajouter,
    [string] $Date,
    [string] $Heure  = '11:00',
    [string] $Format,
    [string] $Sujet,
    [string] $Libelle,
    [string] $Statut = 'prevu',
    [string[]] $Canaux = @(),
    [string] $Note
)

$ErrorActionPreference = 'Stop'

$REPO     = 'C:\Projets\perfecoconsulting'
$REGISTRE = Join-Path $REPO 'automation-agent\publications.json'

if (-not (Test-Path $REGISTRE)) { throw "Registre introuvable : $REGISTRE" }

$utf8 = New-Object System.Text.UTF8Encoding($false)
$reg  = [System.IO.File]::ReadAllText($REGISTRE, $utf8) | ConvertFrom-Json

$nowNC   = [System.DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(11))
$today   = $nowNC.Date

function Save-Registre {
    $reg.derniere_maj = $nowNC.ToString('yyyy-MM-dd')
    $reg.publications = @($reg.publications | Sort-Object date_nc, heure_nc)
    $json = $reg | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($REGISTRE, $json + "`n", $utf8)
}

# ---------------------------------------------------------------------------
# -Ajouter
# ---------------------------------------------------------------------------
if ($Ajouter) {
    if (-not $Date -or -not $Format) { throw "-Ajouter exige au moins -Date et -Format." }
    $id = "$Date-$Format"
    if ($reg.publications | Where-Object { $_.id -eq $id }) {
        throw "Une publication porte deja l'id '$id'. Modifier l'entree existante plutot que d'en creer une seconde."
    }
    $e = [ordered]@{
        id = $id; date_nc = $Date; heure_nc = $Heure; format = $Format
        libelle = $Libelle; sujet = $Sujet; semaine = $null; canaux = $Canaux
        statut = $Statut; source = $null; bascule = $null; preuve = $null; note = $Note
    }
    $reg.publications += [pscustomobject]$e
    Save-Registre
    Write-Host "Ajoute : $id  [$Statut]" -ForegroundColor Green
    return
}

# ---------------------------------------------------------------------------
# -Rafraichir : le statut est DÉRIVÉ des fichiers réels, jamais déclaré.
# ---------------------------------------------------------------------------
if ($Rafraichir) {
    Write-Host "Rafraichissement depuis les files d'attente reelles..." -ForegroundColor Cyan
    $changements = 0

    foreach ($e in $reg.publications) {
        # On ne touche jamais au passé : ce qui est publié est un fait acquis.
        if ($e.statut -like 'publie*' -or $e.statut -eq 'annule') { continue }

        $d = [datetime]::ParseExact($e.date_nc, 'yyyy-MM-dd', $null)
        if ($d -lt $today) {
            # Échéance passée mais jamais marquée publiée : anomalie, on la signale.
            if ($e.statut -ne 'echeance_depassee') {
                $e.statut = 'echeance_depassee'
                $changements++
            }
            continue
        }

        $fmt = $e.format
        if ($fmt -notin @('mardi', 'jeudi', 'vendredi')) { continue }

        $ancien = $e.statut
        $file    = Join-Path $REPO "automation-queue\$fmt.json"
        $nouveau = 'prevu'
        $src     = $null

        # 1) La file d'attente porte-t-elle DÉJÀ cette date, avec un message non vide ?
        if (Test-Path $file) {
            try {
                $q = [System.IO.File]::ReadAllText($file, $utf8) | ConvertFrom-Json
                $msg = $q.social_post.message
                if ($q.date_prevue -eq $e.date_nc -and -not [string]::IsNullOrWhiteSpace($msg)) {
                    $nouveau = 'en_file'; $src = "automation-queue/$fmt.json"
                }
            } catch { }
        }

        # 2) Sinon, un fichier de staging la porte-t-il ?
        if ($nouveau -eq 'prevu') {
            $candidats = Get-ChildItem (Join-Path $REPO 'automation-queue') -Filter "$fmt-*pret.json" -ErrorAction SilentlyContinue
            foreach ($c in $candidats) {
                try {
                    $s = [System.IO.File]::ReadAllText($c.FullName, $utf8) | ConvertFrom-Json
                    $msg = $s.social_post.message
                    if ($s.date_prevue -eq $e.date_nc -and -not [string]::IsNullOrWhiteSpace($msg)) {
                        $nouveau = 'en_staging'; $src = "automation-queue/$($c.Name)"
                        break
                    }
                } catch { }
            }
        }

        if ($nouveau -ne $ancien -or ($src -and $e.source -ne $src)) {
            $e.statut = $nouveau
            if ($src) { $e.source = $src }
            $changements++
            Write-Host ("  {0} : {1} -> {2}" -f $e.id, $ancien, $nouveau) -ForegroundColor Yellow
        }
    }

    if ($changements -gt 0) { Save-Registre; Write-Host "$changements changement(s) enregistre(s)." -ForegroundColor Green }
    else { Write-Host "  Aucun changement : le registre reflete deja l'etat reel." -ForegroundColor DarkGray }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Affichage
# ---------------------------------------------------------------------------
$icone = @{
    'publie'                = '[OK]  '
    'publie_hors_pipeline'  = '[MAIN]'
    'en_file'               = '[FILE]'
    'en_staging'            = '[STAG]'
    'en_production'         = '[PROD]'
    'prevu'                 = '[ ]   '
    'echec'                 = '[KO]  '
    'echeance_depassee'     = '[!!]  '
    'annule'                = '[--]  '
}
$couleur = @{
    'publie' = 'Green'; 'publie_hors_pipeline' = 'Magenta'; 'en_file' = 'Green'
    'en_staging' = 'Yellow'; 'en_production' = 'Yellow'; 'prevu' = 'Gray'
    'echec' = 'Red'; 'echeance_depassee' = 'Red'; 'annule' = 'DarkGray'
}

Write-Host ""
Write-Host "PLANNING DES PUBLICATIONS PerfEco" -ForegroundColor Cyan
Write-Host ("Aujourd'hui : {0} (heure NC)   —   registre a jour au {1}" -f $nowNC.ToString('dddd dd/MM/yyyy HH:mm'), $reg.derniere_maj) -ForegroundColor DarkGray
Write-Host ("=" * 78) -ForegroundColor DarkGray

$limite = $today.AddDays($Jours)
$sel = $reg.publications | Where-Object {
    $d = [datetime]::ParseExact($_.date_nc, 'yyyy-MM-dd', $null)
    ($Tout) -or ($d -ge $today -and $d -le $limite) -or ($_.statut -eq 'echeance_depassee')
} | Sort-Object date_nc, heure_nc

if (-not $sel) { Write-Host "  Rien dans la fenetre demandee." -ForegroundColor DarkYellow }

$dernierJour = ''
foreach ($e in $sel) {
    $d = [datetime]::ParseExact($e.date_nc, 'yyyy-MM-dd', $null)
    $delta = [int]($d - $today).TotalDays
    $quand = if ($delta -eq 0) { "AUJOURD'HUI" } elseif ($delta -eq 1) { "demain" }
             elseif ($delta -gt 0) { "J-$delta" } else { "il y a $([Math]::Abs($delta)) j" }

    $jour = $d.ToString('ddd dd/MM')
    if ($jour -ne $dernierJour) { Write-Host ""; $dernierJour = $jour }

    $c = $couleur[$e.statut]; if (-not $c) { $c = 'Gray' }
    $i = $icone[$e.statut];   if (-not $i) { $i = '[?]   ' }

    Write-Host ("{0} {1}  {2,-5}  {3,-11} {4,-22} {5}" -f `
        $i, $jour, $e.heure_nc, $quand, $e.format, $e.sujet) -ForegroundColor $c

    if ($e.bascule) { Write-Host ("            bascule : {0}" -f $e.bascule) -ForegroundColor DarkCyan }
    if ($e.note)    { Write-Host ("            {0}" -f $e.note) -ForegroundColor DarkYellow }
}

# ---------------------------------------------------------------------------
# Alertes — la règle J-7 appliquée au registre
# ---------------------------------------------------------------------------
$seuil = 7
$enRetard = $reg.publications | Where-Object {
    # Seuls les formats qui exigent une PRODUCTION de contenu. La republication du
    # samedi reprend un post existant et n'a rien à produire ; un post ad hoc est par
    # nature non planifié. Les inclure ferait crier l'alerte sans objet, et une alerte
    # qui crie pour rien finit par ne plus être lue.
    $_.format -in @('mardi', 'jeudi', 'vendredi') -and
    $_.statut -in @('prevu', 'en_production', 'echeance_depassee') -and
    ([datetime]::ParseExact($_.date_nc, 'yyyy-MM-dd', $null) -ge $today) -and
    ([int](([datetime]::ParseExact($_.date_nc, 'yyyy-MM-dd', $null)) - $today).TotalDays) -le $seuil
}

Write-Host ""
Write-Host ("=" * 78) -ForegroundColor DarkGray
if ($enRetard) {
    Write-Host "A PRODUIRE — echeance a J-$seuil ou moins, contenu pas encore pret :" -ForegroundColor Red
    foreach ($e in $enRetard) {
        $j = [int](([datetime]::ParseExact($e.date_nc, 'yyyy-MM-dd', $null)) - $today).TotalDays
        Write-Host ("  J-{0}  {1}  {2}  ({3})" -f $j, $e.date_nc, $e.format, $e.statut) -ForegroundColor Red
    }
    Write-Host "  -> Etape 1quater de perfeco-rappel-quotidien : PRODUIRE, pas seulement alerter." -ForegroundColor Red
} else {
    Write-Host "Aucune echeance a J-$seuil ou moins sans contenu pret." -ForegroundColor Green
}

$horsPipeline = $reg.publications | Where-Object { $_.statut -eq 'publie_hors_pipeline' }
if ($horsPipeline) {
    Write-Host ""
    Write-Host "Publications hors pipeline enregistrees (a prendre en compte pour l'espacement" -ForegroundColor Magenta
    Write-Host "et pour ne pas resservir les memes chiffres) :" -ForegroundColor Magenta
    foreach ($e in $horsPipeline) {
        Write-Host ("  {0}  {1}" -f $e.date_nc, $e.sujet) -ForegroundColor Magenta
    }
}
Write-Host ""
