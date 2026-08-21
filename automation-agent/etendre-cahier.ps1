<#
.SYNOPSIS
    Maintient le cahier des publications à 6 mois glissants, calcule les jours fériés
    NC, détecte les collisions et ouvre les arbitrages qui appellent une décision.

.DESCRIPTION
    Demande de Jean-Michel, 21/08/2026 :
      « Les 6 mois sont-ils renouvelables automatiquement, soit l'ensemble est-il
        maintenant généré automatiquement ? Sauf s'il y a des questions, je dois être
        informé pour prendre les bonnes décisions. »

    Trois choses jusqu'ici faites à la main, donc condamnées à se périmer :
      1. L'horizon était figé au 28/02/2027 — il ne reculait pas.
      2. Les jours fériés étaient saisis en dur pour 2026-2027. Or quatre d'entre eux
         sont MOBILES (lundi de Pâques, Ascension, lundi de Pentecôte) et se recalculent
         chaque année. Une liste figée est fausse dès l'année suivante.
      3. Les décisions à prendre étaient visibles, mais seulement si on lançait la
         commande. Rien ne les portait à Jean-Michel.

    Ce script est IDEMPOTENT : le relancer ne crée pas de doublon et ne réouvre jamais
    un arbitrage déjà tranché. Il peut donc tourner tous les jours sans risque.

.PARAMETER Mois
    Profondeur d'horizon à garantir. Défaut : 6.

.PARAMETER Silencieux
    N'affiche que les arbitrages ouverts (utilisé par les routines).

.EXAMPLE
    .\etendre-cahier.ps1
    .\etendre-cahier.ps1 -Mois 9
#>

[CmdletBinding()]
param(
    [int]    $Mois = 6,
    [switch] $Silencieux
)

$ErrorActionPreference = 'Stop'

$REPO     = 'C:\Projets\perfecoconsulting'
$REGISTRE = Join-Path $REPO 'automation-agent\publications.json'
$utf8     = New-Object System.Text.UTF8Encoding($false)

$reg   = [System.IO.File]::ReadAllText($REGISTRE, $utf8) | ConvertFrom-Json
$nowNC = [System.DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(11))
$today = $nowNC.Date
$cible = $today.AddMonths($Mois)

# ---------------------------------------------------------------------------
# Jours fériés de Nouvelle-Calédonie — CALCULÉS, jamais saisis.
#
# Les fériés NC = les 11 de métropole + le 24 septembre (Fête de la Citoyenneté).
# Quatre sont mobiles et dépendent de Pâques : c'est la raison d'être de ce calcul.
# ---------------------------------------------------------------------------
function Get-Paques {
    param([int] $Annee)
    # Algorithme grégorien anonyme (Meeus/Jones/Butcher) — exact, sans table.
    $a = $Annee % 19; $b = [math]::Floor($Annee / 100); $c = $Annee % 100
    $d = [math]::Floor($b / 4); $e = $b % 4
    $f = [math]::Floor(($b + 8) / 25); $g = [math]::Floor(($b - $f + 1) / 3)
    $h = (19 * $a + $b - $d - $g + 15) % 30
    $i = [math]::Floor($c / 4); $k = $c % 4
    $l = (32 + 2 * $e + 2 * $i - $h - $k) % 7
    $m = [math]::Floor(($a + 11 * $h + 22 * $l) / 451)
    $mois = [math]::Floor(($h + $l - 7 * $m + 114) / 31)
    $jour = (($h + $l - 7 * $m + 114) % 31) + 1
    return Get-Date -Year $Annee -Month $mois -Day $jour -Hour 0 -Minute 0 -Second 0
}

function Get-FeriesNC {
    param([int] $Annee)
    $p = Get-Paques $Annee
    @{
        (Get-Date -Year $Annee -Month 1  -Day 1).ToString('yyyy-MM-dd')  = "Jour de l'An"
        $p.AddDays(1).ToString('yyyy-MM-dd')                              = 'Lundi de Pâques'
        (Get-Date -Year $Annee -Month 5  -Day 1).ToString('yyyy-MM-dd')  = 'Fête du Travail'
        (Get-Date -Year $Annee -Month 5  -Day 8).ToString('yyyy-MM-dd')  = 'Victoire 1945'
        $p.AddDays(39).ToString('yyyy-MM-dd')                             = 'Ascension'
        $p.AddDays(50).ToString('yyyy-MM-dd')                             = 'Lundi de Pentecôte'
        (Get-Date -Year $Annee -Month 7  -Day 14).ToString('yyyy-MM-dd') = 'Fête Nationale'
        (Get-Date -Year $Annee -Month 8  -Day 15).ToString('yyyy-MM-dd') = 'Assomption'
        (Get-Date -Year $Annee -Month 9  -Day 24).ToString('yyyy-MM-dd') = 'Fête de la Citoyenneté (NC)'
        (Get-Date -Year $Annee -Month 11 -Day 1).ToString('yyyy-MM-dd')  = 'Toussaint'
        (Get-Date -Year $Annee -Month 11 -Day 11).ToString('yyyy-MM-dd') = 'Armistice'
        (Get-Date -Year $Annee -Month 12 -Day 25).ToString('yyyy-MM-dd') = 'Noël'
    }
}

$feries = @{}
foreach ($an in $today.Year..$cible.Year) {
    (Get-FeriesNC $an).GetEnumerator() | ForEach-Object { $feries[$_.Key] = $_.Value }
}

# Règles de décalage — celles posées par Jean-Michel le 21/08/2026.
#
# ⚠️ Nom en `Regles` et NON `$REPLI` : une variable locale `$repli` existe plus bas, et
# PowerShell ne distingue pas la casse — `$repli = '2026-09-23'` écrasait la table de
# règles dès la première itération, et toutes les collisions suivantes se décalaient
# de zéro jour (donc restaient posées sur le jour férié). Bug constaté au 1er essai.
$Regles = @{
    'mardi'    = @{ Decalage = -1; Vers = 'lundi'    }
    'jeudi'    = @{ Decalage = -1; Vers = 'mercredi' }
    'vendredi' = @{ Decalage =  1; Vers = 'samedi'   }
}

$existants = @{}
foreach ($p in $reg.publications) { $existants[$p.id] = $p }

$ajouts = @()
$nouveauxArbitrages = @()

function Nouvelle-Entree {
    param($Date, $Format, $Libelle, $Sujet, $Canaux, $Note, $Statut = 'prevu', $Arbitrage = $null)
    [pscustomobject]@{
        id = "$Date-$Format"; date_nc = $Date; heure_nc = '11:00'; format = $Format
        libelle = $Libelle; sujet = $Sujet; semaine = $null; canaux = $Canaux
        statut = $Statut; source = $null; bascule = $null; preuve = $null
        note = $Note; arbitrage = $Arbitrage
    }
}

$C3 = @('linkedin_company','linkedin_perso','facebook')
$C2 = @('linkedin_company','facebook')
$LIB = @{ mardi = 'Post long / carrousel'; jeudi = 'Post court'; vendredi = 'Veille économique NC' }
$CAN = @{ mardi = $C3; jeudi = $C2; vendredi = $C3 }

# ---------------------------------------------------------------------------
# Parcours des semaines jusqu'à l'horizon
# ---------------------------------------------------------------------------
$d = $today
while ($d -le $cible) {
    if ($d.DayOfWeek -eq [DayOfWeek]::Tuesday) {
        foreach ($fmt in @('mardi','jeudi','vendredi')) {
            $offset = @{ mardi = 0; jeudi = 2; vendredi = 3 }[$fmt]
            $dateNormale = $d.AddDays($offset)
            $iso = $dateNormale.ToString('yyyy-MM-dd')

            # Cette date est-elle déjà couverte, à sa date normale OU à une date de repli ?
            $dateRepli = $dateNormale.AddDays($Regles[$fmt].Decalage).ToString('yyyy-MM-dd')
            # Couvert si le créneau existe à sa date normale OU à sa date de repli.
            # Le second cas est essentiel : une décision déjà prise a créé l'entrée au
            # jour de repli, et la rouvrir chaque jour ferait réapparaître une question
            # tranchée — le plus sûr moyen de faire ignorer les alertes.
            $dejaLa = $existants.ContainsKey("$iso-$fmt") -or $existants.ContainsKey("$dateRepli-$fmt")
            if ($dejaLa) { continue }

            if ($feries.ContainsKey($iso)) {
                # Collision : on crée le créneau à la date de REPLI, et on ouvre un arbitrage.
                $fete = $feries[$iso]
                $note = "Le $iso est férié en Nouvelle-Calédonie ($fete). Règle du 21/08/2026 : " +
                        "un $fmt férié bascule vers le $($Regles[$fmt].Vers). Date proposée : $dateRepli."
                $arb = [pscustomobject]@{
                    statut   = 'ouvert'
                    question = "$fete tombe le $iso, un jour de $fmt. Décaler au $($Regles[$fmt].Vers) $dateRepli, ou sauter cette semaine ?"
                    echeance = $dateNormale.AddDays(-9).ToString('yyyy-MM-dd')
                    ouvert_le = $today.ToString('yyyy-MM-dd')
                }
                $ajouts += Nouvelle-Entree -Date $dateRepli -Format $fmt `
                    -Libelle "$($LIB[$fmt]) — ⚠️ décalé ($fete le $iso)" -Sujet 'à définir' `
                    -Canaux $CAN[$fmt] -Note $note -Arbitrage $arb
                $ajouts += Nouvelle-Entree -Date $iso -Format 'ferie' `
                    -Libelle "JOUR FÉRIÉ — $fete" -Sujet 'aucune publication' -Canaux @() `
                    -Note "Créneau $fmt reporté au $dateRepli." -Statut 'annule'
                $nouveauxArbitrages += $arb
            }
            else {
                $ajouts += Nouvelle-Entree -Date $iso -Format $fmt -Libelle $LIB[$fmt] `
                    -Sujet 'à définir' -Canaux $CAN[$fmt] -Note $null
            }
        }
    }
    $d = $d.AddDays(1)
}

if ($ajouts.Count -gt 0) {
    $reg.publications = @($reg.publications) + $ajouts | Sort-Object date_nc, heure_nc
    # L'horizon ne doit jamais RECULER : un run à 6 mois ne doit pas effacer une
    # extension manuelle plus lointaine.
    $horizonActuel = if ($reg._horizon) { $reg._horizon } else { '' }
    $nouvelHorizon = if ($cible.ToString('yyyy-MM-dd') -gt $horizonActuel) { $cible.ToString('yyyy-MM-dd') } else { $horizonActuel }
    $reg | Add-Member -NotePropertyName '_horizon' -NotePropertyValue $nouvelHorizon -Force
    $reg.derniere_maj = $today.ToString('yyyy-MM-dd')
    [System.IO.File]::WriteAllText($REGISTRE, ($reg | ConvertTo-Json -Depth 8) + "`n", $utf8)
}

if (-not $Silencieux) {
    Write-Host ""
    Write-Host "Cahier étendu — horizon garanti : $($cible.ToString('dd/MM/yyyy')) ($Mois mois)" -ForegroundColor Cyan
    Write-Host "  $($ajouts.Count) créneau(x) ajouté(s), $($reg.publications.Count) au total." -ForegroundColor Gray
    Write-Host "  Jours fériés calculés (Pâques et dérivés inclus), pas saisis." -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Les arbitrages OUVERTS — c'est ce qui doit remonter à Jean-Michel.
# ---------------------------------------------------------------------------
$ouverts = @($reg.publications | Where-Object { $_.arbitrage -and $_.arbitrage.statut -eq 'ouvert' } |
    Sort-Object { $_.arbitrage.echeance })

Write-Host ""
if ($ouverts.Count -eq 0) {
    if (-not $Silencieux) { Write-Host "Aucun arbitrage en attente." -ForegroundColor Green }
} else {
    Write-Host "ARBITRAGES EN ATTENTE ($($ouverts.Count)) — décision de Jean-Michel" -ForegroundColor Yellow
    foreach ($o in $ouverts) {
        $j = [int](([datetime]::ParseExact($o.arbitrage.echeance,'yyyy-MM-dd',$null)) - $today).TotalDays
        $urgence = if ($j -le 0) { 'Red' } elseif ($j -le 21) { 'Yellow' } else { 'Gray' }
        Write-Host ""
        Write-Host ("  [$($o.date_nc)] $($o.arbitrage.question)") -ForegroundColor $urgence
        Write-Host ("      à trancher avant le $($o.arbitrage.echeance) — dans $j j") -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  Pour trancher : modifier l'entrée dans publications.json (arbitrage.statut = 'pris')," -ForegroundColor DarkGray
    Write-Host "  ou le dire à Claude, qui l'inscrira et appliquera la décision au pipeline." -ForegroundColor DarkGray
}

# Code de sortie : 2 si un arbitrage devient urgent — exploitable par une routine.
$urgents = @($ouverts | Where-Object {
    [int](([datetime]::ParseExact($_.arbitrage.echeance,'yyyy-MM-dd',$null)) - $today).TotalDays -le 21
})
if ($urgents.Count -gt 0) { exit 2 } else { exit 0 }
