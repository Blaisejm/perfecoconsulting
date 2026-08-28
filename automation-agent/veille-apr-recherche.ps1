<#
.SYNOPSIS
    Appels à projets de recherche ouverts (ADEME + thématiques PerfEco) —
    source d'appoint de la routine `veille-marches-publics-nc`.

.DESCRIPTION
    La page https://recherche.ademe.fr/financer-ma-recherche/appels-projets-de-recherche
    ne contient AUCUNE liste : c'est une page d'atterrissage qui renvoie vers le
    portail national appelsprojetsrecherche.fr (ADEME, ANR, Inserm/ANRS-MIE,
    Anses, INCa, régions…). Ne pas la scraper — elle ne rendra jamais rien.

    Le portail expose un export CSV complet et statique :
        https://www.appelsprojetsrecherche.fr/export-csv
    Colonnes : Partenaire ; Titre ; Description ; Date de publication ;
    Date d'ouverture ; Date de clôture ; Lien ; Date de mise à jour.

    Ce script télécharge cet export, ne garde que les appels réellement OUVERTS
    à la date du jour (ouverture passée, clôture à venir) et les restitue en
    JSON compact — jamais le CSV brut, qui pèse ~300 ko.

    SÉLECTION (union de deux motifs, dédupliquée)
      1. « ademe »  — tout appel ADEME ouvert, sans filtre. Le volume est faible
         (une poignée à tout instant), donc on montre tout et l'humain tranche.
      2. « theme »  — tout appel du portail, quel que soit le partenaire, dont
         le titre ou la description touche l'une des thématiques retenues par
         Jean-Michel le 28/08/2026 : énergie, alimentation, mobilité, climat,
         transition écologique.

    Le filtre thématique est bien plus sûr qu'un filtre par mots-clés métier
    (« organisation », « stratégie », « acteurs »…) : mesuré le 28/08/2026, il
    retient 9 appels sur 25 ouverts, tous réellement sur le sujet, là où le
    filtre métier laissait passer des essais cliniques en cancérologie.

    Un thème trouvé dans le TITRE prime sur un thème trouvé dans la
    description : sans cela, un appel à la description fleuve ressort étiqueté
    des cinq thèmes à la fois (cas réel : AQACIA 2026).

.EXAMPLE
    .\veille-apr-recherche.ps1                      # ADEME + thématiques
    .\veille-apr-recherche.ps1 -Json                # idem, JSON pour la routine
    .\veille-apr-recherche.ps1 -Theme energie       # une seule thématique
    .\veille-apr-recherche.ps1 -Tous                # tous les appels ouverts, sans filtre
#>

[CmdletBinding()]
param(
    [ValidateSet('energie', 'alimentation', 'mobilite', 'climat', 'transition-ecologique')]
    [string[]] $Theme,

    [switch] $Tous,
    [switch] $Json,
    [string] $Partenaire = 'ADEME'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$SOURCE = 'https://www.appelsprojetsrecherche.fr/export-csv'

# ---------------------------------------------------------------------------
# Thématiques retenues par Jean-Michel le 28/08/2026.
# Écrites SANS accent : la comparaison se fait sur du texte normalisé.
# ---------------------------------------------------------------------------
$THEMES = [ordered]@{
    'energie'               = @('energie', 'energetique', 'renouvelable', 'photovolta',
                                'eolien', 'hydrogene', 'biogaz', 'reseau de chaleur',
                                'sobriete energetique', 'electricite', 'biomasse')
    'alimentation'          = @('alimentation', 'alimentaire', 'agricole', 'agriculture',
                                'agroecolog', 'agroalimentaire', 'peche', 'aquaculture',
                                'nutrition')
    'mobilite'              = @('mobilite', 'transport', 'logistique', 'vehicule', 'fret')
    'climat'                = @('climat', 'climatique', 'gaz a effet de serre',
                                'decarbonation', 'carbone', 'resilience')
    'transition-ecologique' = @('transition ecologique', 'economie circulaire', 'biodiversite',
                                'developpement durable', 'sobriete', 'dechets', 'recyclage',
                                'pollution', 'qualite de l air', 'ressources naturelles',
                                'ecosystem')
}

# Mots-clés métier PerfEco — ne servent PLUS à sélectionner (trop de bruit),
# seulement à classer ⭐ / 👁 dans le brouillon Gmail.
$KW_FORTE = @(
    'gouvernance', 'evaluation', 'socio-econom', 'socioeconom', 'accompagnement',
    'conduite du changement', 'politique publique', 'jeux d''acteurs',
    'organisationnel', 'management', 'pilotage', 'diagnostic', 'audit',
    'responsabilite societale'
)
$KW_SURVEILLER = @(
    'numerique', 'digital', 'dematerialis', 'systeme d''information',
    'intelligence artificielle', 'donnees', 'logiciel'
)

# ---------------------------------------------------------------------------
# Normalisation : minuscules et accents retirés, pour que « énergie » et
# « energie » se rencontrent.
# ---------------------------------------------------------------------------
function ConvertTo-TexteNu {
    param([string] $Valeur)
    if (-not $Valeur) { return '' }
    $sb = [Text.StringBuilder]::new()
    foreach ($c in $Valeur.ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD).ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') {
            [void] $sb.Append($c)
        }
    }
    return $sb.ToString()
}

function Test-MotsCles {
    param([string] $Texte, [string[]] $Mots)
    foreach ($m in $Mots) { if ($Texte.Contains((ConvertTo-TexteNu $m))) { return $true } }
    return $false
}

# ---------------------------------------------------------------------------
# 1. Récupération de l'export
# ---------------------------------------------------------------------------
try {
    $reponse = Invoke-WebRequest -Uri $SOURCE -UseBasicParsing -TimeoutSec 60 `
                                 -Headers @{ 'User-Agent' = 'Mozilla/5.0 (PerfEco veille)' }
}
catch {
    # En mode -Json, la panne EST la réponse : elle part sur la sortie standard
    # avec un code retour 0. Un code non nul ferait croire à l'appelant que le
    # script lui-même a échoué, et risquerait de faire abandonner toute la
    # routine alors que la Source A reste parfaitement exploitable. C'est le
    # champ `statut` qui porte l'échec, pas le code de sortie.
    if ($Json) {
        @{ statut = 'echec'; source = $SOURCE; erreur = $_.Exception.Message } | ConvertTo-Json -Compress
        exit 0
    }
    Write-Error "Export CSV injoignable : $($_.Exception.Message)"
    exit 1
}

$brut = [Text.Encoding]::UTF8.GetString($reponse.RawContentStream.ToArray()) -replace "`u{FEFF}", ''

# En-têtes explicites : les intitulés d'origine sont accentués et apostrophés,
# ce qui rend leur accès fragile. La 1re ligne redevient donc une ligne de
# données, écartée juste après.
$colonnes = 'Partenaire', 'Titre', 'Description', 'DatePublication',
            'DateOuverture', 'DateCloture', 'Lien', 'DateMaj'

$lignes = $brut | ConvertFrom-Csv -Delimiter ';' -Header $colonnes |
          Where-Object { $_.Partenaire -and $_.Partenaire -ne 'Partenaire' }

# ---------------------------------------------------------------------------
# 2. Appels réellement ouverts aujourd'hui
# ---------------------------------------------------------------------------
$fr  = [Globalization.CultureInfo]::InvariantCulture
$now = Get-Date

function ConvertTo-DateFr {
    param([string] $Valeur)
    $d = [datetime]::MinValue
    if ([datetime]::TryParseExact($Valeur.Trim(), 'dd/MM/yyyy HH:mm', $fr, 'None', [ref] $d)) { return $d }
    return $null
}

# Certaines lignes du portail n'ont AUCUNE date (pré-annonces dont le calendrier
# n'est pas arrêté). On ne peut pas les dire ouvertes, mais on les compte pour
# ne jamais laisser croire que l'export a été lu en entier. L'ADEME, elle, date
# systématiquement ses appels : ce cas ne touche pas son périmètre.
$sansDate = @($lignes | Where-Object { -not (ConvertTo-DateFr $_.DateCloture) })

$themesVoulus = if ($Theme) { $Theme } else { @($THEMES.Keys) }

$ouverts = foreach ($l in $lignes) {
    $cloture   = ConvertTo-DateFr $l.DateCloture
    $ouverture = ConvertTo-DateFr $l.DateOuverture
    if (-not $cloture -or $cloture -lt $now) { continue }
    if ($ouverture -and $ouverture -gt $now)  { continue }

    $titreNu = ConvertTo-TexteNu $l.Titre
    $descNu  = ConvertTo-TexteNu $l.Description

    # Un thème du titre prime sur un thème de la description.
    $principaux = @(); $secondaires = @()
    foreach ($t in $themesVoulus) {
        if     (Test-MotsCles $titreNu $THEMES[$t]) { $principaux  += $t }
        elseif (Test-MotsCles $descNu  $THEMES[$t]) { $secondaires += $t }
    }
    if ($principaux.Count) { $themesRetenus = $principaux;              $ou = 'titre' }
    else                   { $themesRetenus = @($secondaires | Select-Object -First 2); $ou = 'description' }

    $texteNu = "$titreNu $descNu"
    $pert = if     (Test-MotsCles $texteNu $KW_FORTE)      { 'forte' }
            elseif (Test-MotsCles $texteNu $KW_SURVEILLER) { 'surveiller' }
            else                                           { 'autre' }

    $estAdeme = $l.Partenaire -like "*$Partenaire*"

    [pscustomobject]@{
        partenaire     = $l.Partenaire.Trim()
        titre          = $l.Titre.Trim()
        resume         = (($l.Description -replace '\s+', ' ').Trim())
        ouverture      = if ($ouverture) { $ouverture.ToString('dd/MM/yyyy') } else { '' }
        cloture        = $cloture.ToString('dd/MM/yyyy HH:mm')
        jours_restants = [int] ($cloture - $now).TotalDays
        lien           = $l.Lien.Trim()
        themes         = @($themesRetenus)
        themes_source  = if ($themesRetenus.Count) { $ou } else { '' }
        pertinence     = $pert
        motif          = if ($estAdeme -and $themesRetenus.Count) { 'ademe+theme' }
                         elseif ($estAdeme)                       { 'ademe' }
                         elseif ($themesRetenus.Count)            { 'theme' }
                         else                                     { '' }
    }
}

# ---------------------------------------------------------------------------
# 3. Périmètre
# ---------------------------------------------------------------------------
if ($Tous) {
    $retenus   = @($ouverts)
    $perimetre = 'tous les appels ouverts du portail, sans filtre'
}
else {
    $retenus = @($ouverts | Where-Object { $_.motif })
    $libThemes = if ($Theme) { $Theme -join ', ' } else { 'toutes thematiques' }
    $perimetre = "partenaire $Partenaire (sans filtre) + thematiques PerfEco [$libThemes]"
}

$retenus = @($retenus | Sort-Object { [int] $_.jours_restants })

# Le résumé est utile mais verbeux : on le tronque pour l'aval.
foreach ($r in $retenus) {
    if ($r.resume.Length -gt 400) { $r.resume = $r.resume.Substring(0, 400).TrimEnd() + '…' }
}

# ---------------------------------------------------------------------------
# 4. Restitution
# ---------------------------------------------------------------------------
if ($Json) {
    [pscustomobject]@{
        statut             = 'succes'
        source             = $SOURCE
        consulte_le        = $now.ToString('dd/MM/yyyy HH:mm')
        perimetre          = $perimetre
        thematiques        = @($themesVoulus)
        lus                = @($lignes).Count
        ouverts            = @($ouverts).Count
        retenus            = $retenus.Count
        annonces_sans_date = $sansDate.Count
        appels             = $retenus
    } | ConvertTo-Json -Depth 4
    exit 0
}

Write-Host ""
Write-Host "Appels a projets de recherche ouverts" -ForegroundColor Cyan
Write-Host "  $perimetre" -ForegroundColor DarkGray
Write-Host ("-" * 78) -ForegroundColor DarkGray
Write-Host ("{0} lignes lues, {1} ouvertes au {2}, {3} retenues." -f `
    @($lignes).Count, @($ouverts).Count, $now.ToString('dd/MM/yyyy'), $retenus.Count)
if ($sansDate.Count) {
    Write-Host ("{0} annonce(s) sans date de cloture, non classables — hors decompte." -f $sansDate.Count) -ForegroundColor DarkYellow
}

if (-not $retenus.Count) {
    Write-Host ""
    Write-Host "Aucun appel ouvert sur ce perimetre aujourd'hui." -ForegroundColor Yellow
    exit 0
}

foreach ($r in $retenus) {
    $etiq = if ($r.themes.Count) { $r.themes -join ', ' } else { '-' }
    Write-Host ""
    Write-Host ("[{0}] {1}" -f $r.motif, $r.titre) -ForegroundColor White
    Write-Host ("  {0} — cloture {1} (J-{2})" -f $r.partenaire, $r.cloture, $r.jours_restants) -ForegroundColor DarkGray
    Write-Host ("  themes : {0} (vus dans le {1}) — pertinence {2}" -f $etiq, $r.themes_source, $r.pertinence) -ForegroundColor DarkGray
    Write-Host ("  {0}" -f $r.lien) -ForegroundColor DarkGray
}
Write-Host ""
