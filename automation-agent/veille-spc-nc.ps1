<#
.SYNOPSIS
    Avis de marchés « Services » ouverts de la Communauté du Pacifique (CPS / SPC)
    — source d'appoint de la routine `veille-marches-publics-nc`.

.DESCRIPTION
    Ajoutée le 12/09/2026 à la demande de Jean-Michel. La CPS est basée à Nouméa
    et publie des marchés de services (consultances, études nationales, appuis
    institutionnels, feuilles de route) directement dans le champ de PerfEco :
    monter des projets, chercher des financements, constituer des consortiums.

    DEUX CATALOGUES, PAS UNE TRADUCTION
        EN : https://www.spc.int/procurement
        FR : https://www.spc.int/fr/achats
    Les deux pages portent des jeux d'avis DIFFÉRENTS, sans recoupement (vérifié
    le 12/09/2026 : zéro référence commune). La page FR n'est pas la traduction
    de la page EN, c'est un sous-ensemble traduit et laissé en jachère — ce
    jour-là, ses 9 avis « En diffusion » étaient TOUS clos, le plus récent depuis
    le 03/08/2026 et les plus anciens depuis 2023.

    On lit quand même les deux : un avis destiné aux territoires francophones
    (NC, Polynésie, Wallis) peut n'exister que côté FR, et une requête de plus
    ne coûte rien.

    LE STATUT DU SITE NE FAIT PAS FOI
    Le filtre « Advertised / En diffusion » laisse passer des avis clos depuis
    des années. C'est la DATE DE CLÔTURE qui décide ici, jamais le statut.

    FILTRAGE
    Les deux pages sont interrogées avec les filtres Drupal (mêmes identifiants
    dans les deux langues) :
        field_tender_grant_status_target_id=2247   (Advertised / En diffusion)
        field_tender_category_target_id=2209       (Services)
    « Services » écarte déjà Goods (2210) et Works (2211), c'est-à-dire tout
    l'achat de fournitures et de travaux. Le volume restant est faible — une
    douzaine d'avis — donc AUCUN filtre par mots-clés n'est appliqué : on montre
    tout, et c'est Jean-Michel qui tranche.

    Chaque avis est en revanche ÉTIQUETÉ sur les deux axes PerfEco :
        performance  — évaluation, pilotage, organisation, SI/données, qualité…
        institutions — gouvernance, politique publique, cadre réglementaire…
    Un avis sans étiquette n'est pas écarté, il est simplement classé en fin de
    liste (cas réel : « Occupational Preventive Medicine Services »).

.EXAMPLE
    .\veille-spc-nc.ps1                 # lisible à l'écran
    .\veille-spc-nc.ps1 -Json           # JSON pour la routine
    .\veille-spc-nc.ps1 -Axe institutions
#>

[CmdletBinding()]
param(
    [ValidateSet('performance', 'institutions')]
    [string[]] $Axe,

    [switch] $Json
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$FILTRE  = 'field_tender_grant_status_target_id=2247&field_tender_category_target_id=2209'
$SOURCES = @(
    @{ Langue = 'en'; Url = "https://www.spc.int/procurement?$FILTRE" }
    @{ Langue = 'fr'; Url = "https://www.spc.int/fr/achats?$FILTRE" }
)
$BASE = 'https://www.spc.int'

# ---------------------------------------------------------------------------
# Axes PerfEco. Écrits SANS accent : la comparaison se fait sur du texte
# normalisé. Bilingues, la CPS publiant dans les deux langues.
# ---------------------------------------------------------------------------
$AXES = [ordered]@{
    'performance'  = @('performance', 'monitoring', 'evaluation', 'results framework',
                       'strategic plan', 'organisational', 'organizational', 'management',
                       'capacity building', 'capacity development', 'information system',
                       'knowledge management', 'quality', 'audit', 'assessment', 'review',
                       'efficiency', 'roadmap', 'investment plan', 'feasibility', 'data',
                       'digital', 'ict',
                       'suivi', 'pilotage', 'organisation', 'gestion', 'renforcement des capacites',
                       'systeme d information', 'donnees', 'numerique', 'diagnostic',
                       'efficacite', 'feuille de route', 'plan d investissement', 'faisabilite',
                       'qualite')
    'institutions' = @('institutional', 'governance', 'policy', 'legal', 'regulatory',
                       'framework', 'reform', 'public administration', 'legislation',
                       'guidelines', 'human rights', 'gender', 'social inclusion',
                       'coordination', 'partnership', 'national plan', 'ndc', 'strategy',
                       'planning',
                       'institutionnel', 'gouvernance', 'politique', 'juridique',
                       'reglementaire', 'cadre', 'reforme', 'administration', 'legislation',
                       'lignes directrices', 'droits humains', 'genre', 'inclusion sociale',
                       'partenariat', 'strategie', 'planification')
}

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

# ---------------------------------------------------------------------------
# Une ligne du tableau Drupal : référence, lien, intitulé, puis le bloc de
# dates qui suit dans la même cellule.
# ---------------------------------------------------------------------------
$RX_LIGNE = [regex]::new(
    'views-field-field-reference-no-[^"]*">\s*([^<]*?)\s*</td>.*?' +
    'views-field-field-amendment-s-to-procurement"><a href="([^"]+)">(.*?)</a>(.*?)</td>',
    [Text.RegularExpressions.RegexOptions]::Singleline)

$RX_CLOTURE = [regex]::new('(?:Closing\s*Date|Date\s+de\s+cl\S*ture)\s*:?\s*<time datetime="([^"]+)"',
    [Text.RegularExpressions.RegexOptions]::IgnoreCase)
$RX_PUBLIE  = [regex]::new('(?:Posting\s*date|Date\s+de\s+publication)\s*:?\s*<time datetime="([^"]+)"',
    [Text.RegularExpressions.RegexOptions]::IgnoreCase)

function Get-AvisSpc {
    param([string] $Html, [string] $Langue)
    foreach ($m in $RX_LIGNE.Matches($Html)) {
        $rest = $m.Groups[4].Value

        $mc = $RX_CLOTURE.Match($rest)
        if (-not $mc.Success) { continue }   # sans date de clôture, inclassable

        $titre = [Net.WebUtility]::HtmlDecode(($m.Groups[3].Value -replace '<[^>]+>', '')).Trim()
        $mp    = $RX_PUBLIE.Match($rest)

        [pscustomobject]@{
            reference = $m.Groups[1].Value.Trim()
            titre     = $titre
            url       = $BASE + $m.Groups[2].Value
            langue    = $Langue
            brut_cl   = $mc.Groups[1].Value
            brut_pub  = if ($mp.Success) { $mp.Groups[1].Value } else { '' }
        }
    }
}

# ---------------------------------------------------------------------------
# 1. Récupération des deux catalogues
# ---------------------------------------------------------------------------
$lignes  = @()
$pannes  = @()
foreach ($s in $SOURCES) {
    try {
        $r = Invoke-WebRequest -Uri $s.Url -UseBasicParsing -TimeoutSec 60 `
                               -Headers @{ 'User-Agent' = 'Mozilla/5.0 (PerfEco veille)' }
        $html = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
        $lignes += @(Get-AvisSpc -Html $html -Langue $s.Langue)
    }
    catch {
        $pannes += "$($s.Langue) : $($_.Exception.Message)"
    }
}

# Les DEUX catalogues muets : c'est un échec. Un seul : on continue en le disant.
if ($pannes.Count -eq $SOURCES.Count) {
    if ($Json) {
        # La panne EST la réponse : code retour 0, l'échec est porté par `statut`.
        @{ statut = 'echec'; source = 'spc.int'; erreur = ($pannes -join ' | ') } | ConvertTo-Json -Compress
        exit 0
    }
    Write-Error "CPS injoignable : $($pannes -join ' | ')"
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Avis réellement ouverts, dédupliqués sur la référence
# ---------------------------------------------------------------------------
$now      = Get-Date
$axesVoulus = if ($Axe) { $Axe } else { @($AXES.Keys) }
$vus      = @{}
$ouverts  = @()

foreach ($l in $lignes) {
    $cloture = $null
    try   { $cloture = [datetimeoffset]::Parse($l.brut_cl).LocalDateTime }
    catch { continue }
    if ($cloture -lt $now) { continue }

    $cle = if ($l.reference) { $l.reference } else { $l.url }
    if ($vus.ContainsKey($cle)) { continue }
    $vus[$cle] = $true

    # NE PAS renommer $axesTrouves en $axes : PowerShell ignore la casse des noms
    # de variables, donc $axes ET $AXES désignent la même chose. Un `$axes = @()`
    # écrase le dictionnaire de mots-clés au premier avis traité, et tous les
    # suivants ressortent sans étiquette — en silence. Piège vécu le 12/09/2026.
    $titreNu = ConvertTo-TexteNu $l.titre
    $axesTrouves = @()
    foreach ($nomAxe in $axesVoulus) {
        foreach ($k in $AXES[$nomAxe]) {
            if ($titreNu.Contains((ConvertTo-TexteNu $k))) { $axesTrouves += $nomAxe; break }
        }
    }

    $publie = ''
    if ($l.brut_pub) {
        try { $publie = [datetimeoffset]::Parse($l.brut_pub).LocalDateTime.ToString('dd/MM/yyyy') } catch { }
    }

    $ouverts += [pscustomobject]@{
        reference      = $l.reference
        titre          = $l.titre
        url            = $l.url
        langue         = $l.langue
        publie         = $publie
        cloture        = $cloture.ToString('dd/MM/yyyy HH:mm')
        jours_restants = [int] ($cloture - $now).TotalDays
        axes           = @($axesTrouves)
    }
}

if ($Axe) { $retenus = @($ouverts | Where-Object { $_.axes.Count }) }
else      { $retenus = @($ouverts) }

# Les avis étiquetés d'abord, puis par urgence.
$retenus = @($retenus | Sort-Object @{ Expression = { if ($_.axes.Count) { 0 } else { 1 } } },
                                    @{ Expression = { [int] $_.jours_restants } })

# ---------------------------------------------------------------------------
# 3. Restitution
# ---------------------------------------------------------------------------
if ($Json) {
    [pscustomobject]@{
        statut       = 'succes'
        source       = 'spc.int/procurement + spc.int/fr/achats (Services, ouverts)'
        consulte_le  = $now.ToString('dd/MM/yyyy HH:mm')
        axes         = @($axesVoulus)
        lus          = $lignes.Count
        ouverts      = $ouverts.Count
        retenus      = $retenus.Count
        pannes       = @($pannes)
        avis         = $retenus
    } | ConvertTo-Json -Depth 4
    exit 0
}

Write-Host ""
Write-Host "Avis de marches CPS/SPC — categorie Services, ouverts" -ForegroundColor Cyan
Write-Host ("-" * 78) -ForegroundColor DarkGray
Write-Host ("{0} ligne(s) lue(s) sur les 2 catalogues, {1} ouverte(s) au {2}, {3} retenue(s)." -f `
    $lignes.Count, $ouverts.Count, $now.ToString('dd/MM/yyyy'), $retenus.Count)
foreach ($p in $pannes) { Write-Host "  catalogue muet — $p" -ForegroundColor DarkYellow }

if (-not $retenus.Count) {
    Write-Host ""
    Write-Host "Aucun avis de services ouvert aujourd'hui." -ForegroundColor Yellow
    exit 0
}

foreach ($a in $retenus) {
    $etiq = if ($a.axes.Count) { $a.axes -join ', ' } else { 'hors axes PerfEco' }
    Write-Host ""
    Write-Host ("[{0}] {1}" -f $etiq, $a.titre) -ForegroundColor White
    Write-Host ("  {0} — cloture {1} (J-{2}) — {3}" -f $a.reference, $a.cloture, $a.jours_restants, $a.langue) -ForegroundColor DarkGray
    Write-Host ("  {0}" -f $a.url) -ForegroundColor DarkGray
}
Write-Host ""
