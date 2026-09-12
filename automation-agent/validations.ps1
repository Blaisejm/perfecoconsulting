<#
.SYNOPSIS
    Registre central des VALIDATIONS demandées à Jean-Michel, avec le délai de 48 h
    au-delà duquel le système tranche seul.

.DESCRIPTION
    Deux règles posées par Jean-Michel le 12/09/2026 :

      1. « Toutes les routines qui produisent des brouillons de mails ou de rapport
         indiquent leur dénomination dans le mail envoyé, surtout si elles me demandent
         une ou des validations. »

      2. « Je dispose de 48 h pour valider un sujet ou une publication, au-delà le
         système est supposé prendre la meilleure solution, tout seul. Cette règle est
         valide pour toutes les diffusions médias ou publications. »

    La règle 2 est inapplicable sans ce fichier. Une question posée dans un brouillon
    Gmail meurt avec le brouillon : personne ne sait quand elle a été posée, donc
    personne ne peut savoir quand les 48 h sont écoulées. Le registre porte
    l'HORODATAGE D'OUVERTURE et, surtout, L'OPTION PAR DÉFAUT — celle que le système
    appliquera seul.

    C'est pourquoi -Ouvrir REFUSE une demande sans -Defaut : une question sans réponse
    par défaut n'est pas une demande de validation, c'est un blocage déguisé. Le seul
    moyen de garantir qu'une absence de réponse ne bloque rien, c'est d'exiger la
    solution de repli AU MOMENT OÙ LA QUESTION EST POSÉE, pas 48 h plus tard quand
    l'échéance presse.

    -Ouvrir est IDEMPOTENT sur (routine + objet) : une routine rattrapée trois fois de
    suite ne crée pas trois questions et ne remet pas le compteur à zéro. Sans cela, une
    routine qui se rattrape chaque jour repousserait indéfiniment sa propre échéance de
    48 h — la règle ne se déclencherait jamais.

    Le script couvre AUSSI les arbitrages ouverts de publications.json (collisions de
    jours fériés) : ils sont soumis au même délai, leur défaut étant la date de repli
    déjà calculée par etendre-cahier.ps1 selon les règles du 21/08/2026.

    LE COMPTEUR PART DE LA QUESTION POSÉE, PAS DE LA QUESTION DÉTECTÉE
    Erreur trouvée au premier essai, le 12/09/2026 : l'arbitrage « Ascension du jeudi
    6 mai 2027 » a été ouvert par etendre-cahier.ps1 le 21/08/2026 et serait apparu
    « échu depuis 486 h ». Or Jean-Michel ne l'a jamais reçu : perfeco-rappel-quotidien
    ne relaie volontairement pas une question à plus de 21 jours d'échéance, pour ne pas
    noyer les vraies alertes. Trancher d'office une question jamais posée, ce n'est pas
    appliquer la règle des 48 h — c'est la retourner contre son auteur.
    Donc : le délai court à partir de `relaye_le`, la date du PREMIER brouillon Gmail qui
    a effectivement porté la question. Tant que `relaye_le` est absent, l'arbitrage est
    « à poser », jamais « échu ». C'est `-Relayer` qui pose cet horodatage.

.PARAMETER Ouvrir
    Enregistre une demande de validation. Exige -Routine, -Objet, -Question, -Defaut.

.PARAMETER Relayer
    Atteste qu'une question a bien été mise dans un brouillon Gmail, et DÉMARRE son délai
    de 48 h. Pour un arbitrage de publications.json : -Relayer -Id <id-de-publication>.

.PARAMETER Trancher
    Inscrit la décision de Jean-Michel. Exige -Id et -Decision.

.PARAMETER AppliquerDefauts
    Passe toutes les demandes échues en 'tranche_par_defaut'. À n'appeler QU'APRÈS avoir
    réellement appliqué le défaut au contenu — le registre acte une décision exécutée,
    il ne la remplace pas.

.PARAMETER Heures
    Délai accordé. Défaut : 48 (la règle). Ne descendre en dessous que si la publication
    est plus proche que 48 h — utiliser -Avant, qui écrête automatiquement.

.PARAMETER Avant
    Borne dure (ISO). Le délai retenu est le PLUS COURT des deux : 48 h ou cette borne.
    Une question posée 30 h avant la diffusion ne peut pas attendre 48 h.

.OUTPUTS
    Dernière ligne toujours lisible par une routine :
        VALIDATIONS: ouvertes=<n> echues=<n> a_poser=<n>
    Code de sortie : 0 rien en attente · 2 il y a quelque chose à mettre dans le brouillon
    (question en cours, ou question à poser) · 3 au moins une échue — un défaut est à
    appliquer MAINTENANT, avant de produire quoi que ce soit.

.EXAMPLE
    .\validations.ps1
    .\validations.ps1 -Json
    .\validations.ps1 -Ouvrir -Routine mardi-carrousel-creation -Objet "brief W40" `
        -Question "Quel angle pour le carrousel du 29/09 ?" `
        -Options "Tresorerie T3","Decision COMEX" -Defaut "Tresorerie T3 (source la mieux sourcee)" `
        -Publication 2026-09-29-mardi -Avant "2026-09-29T09:00:00+11:00"
    .\validations.ps1 -Trancher -Id v-2026-09-12-01 -Decision "Decision COMEX"
    .\validations.ps1 -AppliquerDefauts
#>

[CmdletBinding()]
param(
    [switch]   $Ouvrir,
    [switch]   $Relayer,
    [switch]   $Trancher,
    [switch]   $AppliquerDefauts,
    [switch]   $Cloturer,
    [switch]   $Json,
    [switch]   $Silencieux,

    [string]   $Id,
    [string]   $Routine,
    [string]   $Objet,
    [string]   $Question,
    [string[]] $Options = @(),
    [string]   $Defaut,
    [string]   $Impact,
    [string]   $Publication,
    [double]   $Heures = 48,
    [string]   $Avant,

    [string]   $Decision,
    [string]   $Par = 'Jean-Michel',
    [string]   $Motif
)

$ErrorActionPreference = 'Stop'

$REPO     = 'C:\Projets\perfecoconsulting'
$REGISTRE = Join-Path $REPO 'automation-agent\validations.json'
$PUBLIS   = Join-Path $REPO 'automation-agent\publications.json'

$utf8  = New-Object System.Text.UTF8Encoding($false)
$nowNC = [System.DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(11))
$FMT   = 'yyyy-MM-ddTHH:mm:sszzz'

if (-not (Test-Path $REGISTRE)) {
    $vide = [ordered]@{
        _lisez_moi            = 'Registre des validations demandees a Jean-Michel. Delai standard 48 h, au-dela le systeme applique le defaut. Regle du 12/09/2026. Ne pas editer a la main : utiliser validations.ps1.'
        delai_standard_heures = 48
        derniere_maj          = $nowNC.ToString('yyyy-MM-dd')
        validations           = @()
    }
    [System.IO.File]::WriteAllText($REGISTRE, (($vide | ConvertTo-Json -Depth 8) + "`n"), $utf8)
}

$reg = [System.IO.File]::ReadAllText($REGISTRE, $utf8) | ConvertFrom-Json
if (-not $reg.validations) { $reg.validations = @() }

function Save-Registre {
    $reg.derniere_maj = $nowNC.ToString('yyyy-MM-dd')
    $json = $reg | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($REGISTRE, ($json + "`n"), $utf8)
}

# Heures restantes avant echeance. Negatif = echu.
function Get-HeuresRestantes {
    param([string] $Echeance)
    try   { $e = [System.DateTimeOffset]::Parse($Echeance) }
    catch { return 0 }   # une echeance illisible est traitee comme echue : jamais de blocage silencieux
    return [math]::Round(($e - $nowNC).TotalHours, 1)
}

# ---------------------------------------------------------------------------
# -Ouvrir
# ---------------------------------------------------------------------------
if ($Ouvrir) {
    if (-not $Routine)  { throw "-Ouvrir exige -Routine (la denomination de la routine qui pose la question)." }
    if (-not $Objet)    { throw "-Ouvrir exige -Objet (libelle court, sert aussi de cle anti-doublon)." }
    if (-not $Question) { throw "-Ouvrir exige -Question." }
    if (-not $Defaut)   { throw "-Ouvrir exige -Defaut : la regle du 12/09/2026 veut qu'une absence de reponse ne bloque RIEN. Pas de defaut = pas de demande recevable." }

    # Idempotence : meme routine + meme objet, deja ouvert => on rend l'existant.
    $deja = @($reg.validations | Where-Object { $_.routine -eq $Routine -and $_.objet -eq $Objet -and $_.statut -eq 'ouvert' })
    if ($deja.Count -gt 0) {
        $e = $deja[0]
        $e.rappels = [int]$e.rappels + 1
        Save-Registre
        if (-not $Silencieux) {
            Write-Host "Demande deja ouverte — echeance INCHANGEE (idempotence)." -ForegroundColor Yellow
            Write-Host "  $($e.id) — a repondre avant $($e.repondre_avant) ($(Get-HeuresRestantes $e.repondre_avant) h)" -ForegroundColor Gray
        }
        if ($Json) { $e | ConvertTo-Json -Depth 6 }
        exit 0
    }

    $jour  = $nowNC.ToString('yyyy-MM-dd')
    $n     = 1 + @($reg.validations | Where-Object { $_.id -like "v-$jour-*" }).Count
    $newId = "v-$jour-{0:d2}" -f $n

    $echeance = $nowNC.AddHours($Heures)
    $ecrete   = $false
    if ($Avant) {
        $borne = [System.DateTimeOffset]::Parse($Avant)
        if ($borne -lt $echeance) { $echeance = $borne; $ecrete = $true }
    }

    $e = [pscustomobject]@{
        id             = $newId
        routine        = $Routine
        objet          = $Objet
        question       = $Question
        options        = @($Options)
        defaut         = $Defaut
        impact         = $Impact
        publication    = $Publication
        ouvert_a       = $nowNC.ToString($FMT)
        repondre_avant = $echeance.ToString($FMT)
        delai_heures   = if ($ecrete) { [math]::Round(($echeance - $nowNC).TotalHours, 1) } else { $Heures }
        ecrete         = $ecrete
        statut         = 'ouvert'
        decision       = $null
        tranche_a      = $null
        par            = $null
        rappels        = 0
    }
    $reg.validations = @($reg.validations) + $e
    Save-Registre

    if (-not $Silencieux) {
        Write-Host "Validation ouverte : $newId" -ForegroundColor Cyan
        Write-Host "  routine : $Routine" -ForegroundColor Gray
        Write-Host "  reponse attendue avant : $($e.repondre_avant) NC" -ForegroundColor Gray
        if ($ecrete) { Write-Host "  delai ECRETE a $($e.delai_heures) h : la diffusion est plus proche que 48 h." -ForegroundColor Yellow }
        Write-Host "  sans reponse, le systeme appliquera : $Defaut" -ForegroundColor Gray
    }
    if ($Json) { $e | ConvertTo-Json -Depth 6 }
    exit 0
}

# ---------------------------------------------------------------------------
# -Relayer : la question est dans un brouillon Gmail -> le delai de 48 h demarre.
# Idempotent : un second passage ne repousse pas l'echeance, il compte un rappel.
# ---------------------------------------------------------------------------
if ($Relayer) {
    if (-not $Id) { throw "-Relayer exige -Id (id de validation, ou id de publication pour un arbitrage calendrier)." }

    $e = @($reg.validations | Where-Object { $_.id -eq $Id })[0]
    if ($e) {
        $e.rappels = [int]$e.rappels + 1
        Save-Registre
        if (-not $Silencieux) { Write-Host "$Id relaye (rappel n$($e.rappels)) - echeance inchangee : $($e.repondre_avant)" -ForegroundColor Gray }
        exit 0
    }

    if (-not (Test-Path $PUBLIS)) { throw "Aucune validation d'id '$Id', et publications.json est introuvable." }
    $pub = [System.IO.File]::ReadAllText($PUBLIS, $utf8) | ConvertFrom-Json
    $p = @($pub.publications | Where-Object { $_.id -eq $Id -and $_.arbitrage })[0]
    if (-not $p) { throw "Aucune validation ni arbitrage d'id '$Id'." }

    if ($p.arbitrage.relaye_le) {
        if (-not $Silencieux) { Write-Host "Arbitrage $Id deja relaye le $($p.arbitrage.relaye_le) - delai de 48 h inchange." -ForegroundColor Gray }
        exit 0
    }
    $p.arbitrage | Add-Member -NotePropertyName 'relaye_le' -NotePropertyValue $nowNC.ToString('yyyy-MM-dd') -Force
    $pub.derniere_maj = $nowNC.ToString('yyyy-MM-dd')
    [System.IO.File]::WriteAllText($PUBLIS, (($pub | ConvertTo-Json -Depth 8) + "`n"), $utf8)
    if (-not $Silencieux) {
        Write-Host "Arbitrage $Id relaye le $($nowNC.ToString('yyyy-MM-dd')) - delai de 48 h demarre." -ForegroundColor Cyan
    }
    exit 0
}

# ---------------------------------------------------------------------------
# -Trancher  /  -Cloturer
# ---------------------------------------------------------------------------
if ($Trancher -or $Cloturer) {
    if (-not $Id) { throw "-Trancher et -Cloturer exigent -Id." }
    $e = @($reg.validations | Where-Object { $_.id -eq $Id })[0]
    if (-not $e) { throw "Aucune validation d'id '$Id'." }

    if ($Trancher) {
        if (-not $Decision) { throw "-Trancher exige -Decision." }
        $e.statut   = 'tranche'
        $e.decision = $Decision
        $e.par      = $Par
    } else {
        $e.statut   = 'caduc'
        $e.decision = if ($Motif) { "sans objet - $Motif" } else { 'sans objet' }
        $e.par      = $Par
    }
    $e.tranche_a = $nowNC.ToString($FMT)
    Save-Registre
    if (-not $Silencieux) { Write-Host "$Id -> $($e.statut) : $($e.decision)" -ForegroundColor Green }
    exit 0
}

# ---------------------------------------------------------------------------
# -AppliquerDefauts : les 48 h sont ecoulees, le systeme a tranche seul.
# ---------------------------------------------------------------------------
if ($AppliquerDefauts) {
    $echues = @($reg.validations | Where-Object {
        $_.statut -eq 'ouvert' -and (Get-HeuresRestantes $_.repondre_avant) -le 0
    })
    if ($Id) { $echues = @($echues | Where-Object { $_.id -eq $Id }) }

    foreach ($e in $echues) {
        $e.statut    = 'tranche_par_defaut'
        $e.decision  = if ($Decision) { $Decision } else { $e.defaut }
        $e.par       = 'systeme (48 h sans reponse - regle du 12/09/2026)'
        $e.tranche_a = $nowNC.ToString($FMT)
        if (-not $Silencieux) {
            Write-Host "DEFAUT APPLIQUE - $($e.id) [$($e.routine)]" -ForegroundColor Magenta
            Write-Host "  $($e.objet) -> $($e.decision)" -ForegroundColor Gray
        }
    }

    # Les arbitrages de publications.json suivent la meme regle : leur defaut est la
    # date de repli, deja creee par etendre-cahier.ps1 selon les regles du 21/08/2026.
    $nbPub = 0
    if (Test-Path $PUBLIS) {
        $pub = [System.IO.File]::ReadAllText($PUBLIS, $utf8) | ConvertFrom-Json
        foreach ($p in @($pub.publications | Where-Object { $_.arbitrage -and $_.arbitrage.statut -eq 'ouvert' })) {
            # Jamais relaye = jamais pose a Jean-Michel : le delai n'a pas commence.
            if (-not $p.arbitrage.relaye_le) { continue }
            $limite = [System.DateTimeOffset]::Parse("$($p.arbitrage.relaye_le)T09:00:00+11:00").AddHours(48)
            if ($nowNC -lt $limite) { continue }
            $p.arbitrage.statut = 'pris'
            $p.arbitrage | Add-Member -NotePropertyName 'decision'   -NotePropertyValue "Defaut applique : la publication reste a la date de repli $($p.date_nc) (regles de decalage du 21/08/2026)." -Force
            $p.arbitrage | Add-Member -NotePropertyName 'tranche_le' -NotePropertyValue $nowNC.ToString('yyyy-MM-dd') -Force
            $p.arbitrage | Add-Member -NotePropertyName 'par'        -NotePropertyValue 'systeme (48 h sans reponse - regle du 12/09/2026)' -Force
            $nbPub++
            if (-not $Silencieux) {
                Write-Host "DEFAUT APPLIQUE - arbitrage $($p.id)" -ForegroundColor Magenta
                Write-Host "  $($p.arbitrage.question)" -ForegroundColor Gray
                Write-Host "  -> maintien au $($p.date_nc)" -ForegroundColor Gray
            }
        }
        if ($nbPub -gt 0) {
            $pub.derniere_maj = $nowNC.ToString('yyyy-MM-dd')
            [System.IO.File]::WriteAllText($PUBLIS, (($pub | ConvertTo-Json -Depth 8) + "`n"), $utf8)
        }
    }

    if ($echues.Count -gt 0) { Save-Registre }
    if (-not $Silencieux -and $echues.Count -eq 0 -and $nbPub -eq 0) {
        Write-Host "Aucun delai de 48 h echu - rien a trancher d'office." -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "DEFAUTS_APPLIQUES: validations=$($echues.Count) arbitrages=$nbPub"
    exit 0
}

# ---------------------------------------------------------------------------
# Affichage par defaut
# ---------------------------------------------------------------------------
$lignes = @()
foreach ($e in @($reg.validations | Where-Object { $_.statut -eq 'ouvert' })) {
    $lignes += [pscustomobject]@{
        id = $e.id; source = 'validations.json'; routine = $e.routine
        objet = $e.objet; question = $e.question; options = @($e.options)
        defaut = $e.defaut; publication = $e.publication
        a_poser = $false; jours_echeance = $null
        repondre_avant = $e.repondre_avant
        heures_restantes = (Get-HeuresRestantes $e.repondre_avant)
    }
}
if (Test-Path $PUBLIS) {
    $pub = [System.IO.File]::ReadAllText($PUBLIS, $utf8) | ConvertFrom-Json
    foreach ($p in @($pub.publications | Where-Object { $_.arbitrage -and $_.arbitrage.statut -eq 'ouvert' })) {
        $jours = $null
        if ($p.arbitrage.echeance) {
            try { $jours = [int]([datetime]::ParseExact($p.arbitrage.echeance,'yyyy-MM-dd',$null) - $nowNC.Date).TotalDays } catch { $jours = $null }
        }
        if ($p.arbitrage.relaye_le) {
            $lim = [System.DateTimeOffset]::Parse("$($p.arbitrage.relaye_le)T09:00:00+11:00").AddHours(48)
            $avant = $lim.ToString($FMT)
            $reste = [math]::Round(($lim - $nowNC).TotalHours, 1)
            $aPoser = $false
        } else {
            $avant = $null
            $reste = $null
            $aPoser = $true
        }
        $lignes += [pscustomobject]@{
            id = $p.id; source = 'publications.json'; routine = 'perfeco-rappel-quotidien (etendre-cahier)'
            objet = "arbitrage calendrier - $($p.format)"; question = $p.arbitrage.question
            options = @(); defaut = "maintien de la date de repli $($p.date_nc)"
            publication = $p.id
            a_poser = $aPoser; jours_echeance = $jours
            repondre_avant = $avant
            heures_restantes = $reste
        }
    }
}

# Trois etats, et l'ordre du filtrage compte : une question jamais posee ne peut pas
# etre echue, quel que soit son age.
$aposer  = @($lignes | Where-Object { $_.a_poser } | Sort-Object { $_.jours_echeance })
$suivies = @($lignes | Where-Object { -not $_.a_poser })
$echues  = @($suivies | Where-Object { $_.heures_restantes -le 0 })
$encours = @($suivies | Where-Object { $_.heures_restantes -gt 0 } | Sort-Object heures_restantes)

if ($Json) {
    [pscustomobject]@{ echues = $echues; ouvertes = $encours; a_poser = $aposer } | ConvertTo-Json -Depth 6
}
elseif (-not $Silencieux) {
    Write-Host ""
    if ($aposer.Count -gt 0) {
        Write-Host "PAS ENCORE POSEES A JEAN-MICHEL ($($aposer.Count)) - le delai de 48 h n'a pas commence" -ForegroundColor Cyan
        foreach ($l in $aposer) {
            $j = if ($null -ne $l.jours_echeance) { "$($l.jours_echeance) j" } else { '?' }
            $quand = if ($null -ne $l.jours_echeance -and $l.jours_echeance -le 21) { 'A METTRE DANS LE PROCHAIN BROUILLON' } else { 'dormante (hors fenetre de 21 j)' }
            Write-Host ""
            Write-Host "  [$($l.id)] $($l.objet) - echeance operationnelle dans $j" -ForegroundColor Gray
            Write-Host "      $($l.question)" -ForegroundColor Gray
            Write-Host "      $quand" -ForegroundColor DarkGray
            Write-Host "      quand elle part : validations.ps1 -Relayer -Id $($l.id)" -ForegroundColor DarkGray
        }
    }
    if ($echues.Count -gt 0) {
        Write-Host ""
        Write-Host "DELAI DE 48 H ECOULE ($($echues.Count)) - le systeme doit trancher SEUL, maintenant" -ForegroundColor Red
        foreach ($l in $echues) {
            Write-Host ""
            Write-Host "  [$($l.id)] $($l.routine)" -ForegroundColor Red
            Write-Host "      $($l.question)" -ForegroundColor Gray
            Write-Host "      defaut a appliquer : $($l.defaut)" -ForegroundColor Yellow
            Write-Host "      echu depuis $([math]::Abs($l.heures_restantes)) h" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "  Applique le defaut au CONTENU, puis : validations.ps1 -AppliquerDefauts" -ForegroundColor DarkGray
    }
    if ($encours.Count -gt 0) {
        Write-Host ""
        Write-Host "EN ATTENTE DE JEAN-MICHEL ($($encours.Count))" -ForegroundColor Yellow
        foreach ($l in $encours) {
            $c = if ($l.heures_restantes -le 12) { 'Yellow' } else { 'Gray' }
            Write-Host ""
            Write-Host "  [$($l.id)] $($l.routine) - $($l.objet)" -ForegroundColor $c
            Write-Host "      $($l.question)" -ForegroundColor Gray
            Write-Host "      reponse avant $($l.repondre_avant) - $($l.heures_restantes) h restantes" -ForegroundColor DarkGray
            Write-Host "      a defaut : $($l.defaut)" -ForegroundColor DarkGray
        }
    }
    if ($lignes.Count -eq 0) { Write-Host "Aucune validation en attente." -ForegroundColor Green }
}

Write-Host ""
Write-Host "VALIDATIONS: ouvertes=$($encours.Count) echues=$($echues.Count) a_poser=$($aposer.Count)"

if ($echues.Count -gt 0) { exit 3 }
if ($encours.Count -gt 0 -or $aposer.Count -gt 0) { exit 2 }
exit 0
