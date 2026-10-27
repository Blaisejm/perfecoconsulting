<#
.SYNOPSIS
    Clôture d'une routine PerfEco : commit horodaté sous le nom de la routine,
    dans les deux dépôts, + ligne de journal listant les fichiers touchés.

.DESCRIPTION
    Posé par Jean-Michel le 21/08/2026 :
    « Tu dois à tout moment savoir précisément quelle routine a travaillé sur un
      fichier et à quel moment. »

    Avant ce script, deux trous :
      1. La zone de suivi (OneDrive\Documents\claude IA) n'était versionnée nulle
         part. SUIVI-AUTOMATISATION.md, source de vérité du dispositif, n'avait
         aucun historique : une écriture erronée était irrattrapable et personne
         ne pouvait dire qui l'avait écrite.
      2. Le journal disait ce qu'une routine avait fait, jamais SUR QUELS FICHIERS.

    Ce script ferme les deux. Le point clé : **le commit est signé du nom de la
    routine**, pas de « Jean-Michel Blaise ». C'est ce qui rend la réponse
    immédiate :

        git log --format="%an %ad" -- <fichier>      → qui, et quand
        git log --author=perfeco-rappel-quotidien    → tout ce qu'elle a touché

.PARAMETER Routine
    Identifiant exact de la tâche planifiée. Devient l'AUTEUR des commits.

.PARAMETER Resultat
    succes | echec | rien-a-faire

.PARAMETER Effet
    Ce qui a CHANGÉ, en clair. Jamais « routine exécutée ».

.PARAMETER Preuve
    Commit, chemin, URL, identifiant de brouillon... ou "aucune".

.PARAMETER Alerte
    Ce qui reste bloqué. Omis = null.

.EXAMPLE
    .\trace-routine.ps1 -Routine "perfeco-rappel-quotidien" -Resultat "succes" `
        -Effet "tableau de bord mis a jour : alerte theme Serie 2 a J-3" `
        -Preuve "brouillon Gmail r-679..." -Alerte "theme non arbitre"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Routine,
    [Parameter(Mandatory = $true)][ValidateSet('succes', 'echec', 'rien-a-faire')][string] $Resultat,
    [Parameter(Mandatory = $true)][string] $Effet,
    [Parameter(Mandatory = $true)][string] $Preuve,
    [string] $Alerte = $null
)

$ErrorActionPreference = 'Continue'

$REPO_PROJET = 'C:\Projets\perfecoconsulting'
$REPO_SUIVI  = 'C:\Users\jmbla\OneDrive\Documents\claude IA'
$JOURNAL     = Join-Path $REPO_PROJET 'automation-agent\journal-executions.jsonl'
$MAIL        = 'contact@perfeco.nc'

# Heure de Nouvelle-Calédonie (UTC+11), quelle que soit l'horloge de la machine.
$nowNC  = [System.DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(11))
$finNC  = $nowNC.ToString("yyyy-MM-ddTHH:mm:sszzz")
$stamp  = $nowNC.ToString("dd/MM/yyyy HH:mm")

$fichiersTouches = @()
$commits         = @()
$pushEchecs      = @()

function Invoke-Git {
    param([string] $Repo, [string[]] $GitArgs)
    Push-Location $Repo
    try   { & git @GitArgs 2>&1; $script:gitCode = $LASTEXITCODE }
    catch { Write-Warning "git $($GitArgs -join ' ') a echoue dans $Repo : $_"; $script:gitCode = 1; $null }
    finally { Pop-Location }
}

# ---------------------------------------------------------------------------
# Push VÉRIFIÉ (ajouté le 27/10/2026, intervention-manuelle, demande de JM).
#
# Avant, le push était jeté dans Out-Null. Du 16 au 27/10/2026, un conflit sur
# publications.json (registre rafraîchi en local, clôturé par GitHub Actions)
# a fait refuser TOUS les push des routines, sans un mot : 3 commits restés en
# local, bascules jamais arrivées sur origin, 5 publications perdues (22, 23,
# 24 et 27/10), et un journal qui affichait « ligne ajoutee et poussee ».
#
# Désormais : push → si refusé, UN pull (fusion) puis nouveau push. Si le pull
# tombe en conflit, la fusion est annulée (dépôt laissé propre, commits locaux
# intacts) et l'échec est RENDU : champ `push_echecs` du journal, `alerte`
# préfixée, ligne `PUSH: ECHEC` en sortie et code de sortie 4. On ne résout
# jamais un conflit automatiquement : c'est une décision humaine.
#
# Le succès ne se déduit pas du code de retour seul : on vérifie que HEAD est
# bien arrivé sur la branche distante.
# ---------------------------------------------------------------------------
# Sortie git lisible : en 5.1, la redirection 2>&1 enveloppe stderr dans des
# ErrorRecord dont l'affichage noie le message. On ne garde que les lignes utiles.
function Resume-Git {
    param($Sortie)
    $lignes = @($Sortie | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -match 'rejected|error|fatal|CONFLICT|conflit' })
    if ($lignes.Count -eq 0) { $lignes = @($Sortie | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ } | Select-Object -First 2) }
    ($lignes -join ' / ')
}

function Push-Verifie {
    param([string] $Repo, [string] $Etiquette)

    $out = Invoke-Git -Repo $Repo -GitArgs @('push', '-q', 'origin', 'HEAD')
    if ($script:gitCode -ne 0) {
        Write-Warning "$Etiquette : push refuse, tentative de fusion avec origin : $(Resume-Git $out)"
        $pull = Invoke-Git -Repo $Repo -GitArgs @('pull', '--no-rebase', '--no-edit', '-q', 'origin', 'HEAD')
        if ($script:gitCode -ne 0) {
            $conflits = @(Invoke-Git -Repo $Repo -GitArgs @('diff', '--name-only', '--diff-filter=U')) -join ', '
            Invoke-Git -Repo $Repo -GitArgs @('merge', '--abort') | Out-Null
            $raison = if ($conflits) { "conflit sur $conflits" } else { Resume-Git $pull }
            $script:pushEchecs += "$Etiquette : push refuse et fusion impossible ($raison) - fusion annulee, commits restes en local"
            return $false
        }
        $out = Invoke-Git -Repo $Repo -GitArgs @('push', '-q', 'origin', 'HEAD')
        if ($script:gitCode -ne 0) {
            $script:pushEchecs += "$Etiquette : push refuse meme apres fusion ($(Resume-Git $out))"
            return $false
        }
    }

    $local  = (Invoke-Git -Repo $Repo -GitArgs @('rev-parse', 'HEAD')) -join ''
    $distant = (Invoke-Git -Repo $Repo -GitArgs @('rev-parse', '@{u}')) -join ''
    if ($script:gitCode -ne 0 -or $local.Trim() -ne $distant.Trim()) {
        $court = $local.Trim(); if ($court.Length -gt 7) { $court = $court.Substring(0, 7) }
        $script:pushEchecs += "$Etiquette : push annonce reussi mais HEAD $court absent de la branche distante"
        return $false
    }
    return $true
}

# ---------------------------------------------------------------------------
# 1. Commit de ce que la routine a modifié, dans chaque dépôt, SOUS SON NOM.
# ---------------------------------------------------------------------------
function Commit-Repo {
    param([string] $Repo, [string] $Etiquette, [switch] $ExcludeJournal)

    if (-not (Test-Path (Join-Path $Repo '.git'))) {
        Write-Warning "$Etiquette : pas un depot git, ignore."
        return
    }

    $porcelain = Invoke-Git -Repo $Repo -GitArgs @('status', '--porcelain')
    if (-not $porcelain) { return }   # rien à commiter : cas normal et fréquent

    $modifies = @($porcelain | ForEach-Object {
        $p = $_.ToString()
        if ($p.Length -gt 3) { $p.Substring(3).Trim('"').Trim() }
    } | Where-Object { $_ })

    # Le journal est commité séparément, à la toute fin (il contient le hash
    # des commits ci-dessus : l'inclure ici créerait une dépendance circulaire).
    if ($ExcludeJournal) {
        $modifies = @($modifies | Where-Object { $_ -notmatch 'journal-executions\.jsonl' })
        if ($modifies.Count -eq 0) { return }
        foreach ($f in $modifies) { Invoke-Git -Repo $Repo -GitArgs @('add', '--', $f) | Out-Null }
    } else {
        Invoke-Git -Repo $Repo -GitArgs @('add', '-A') | Out-Null
    }

    $sujet = "$Routine : $Effet"
    if ($sujet.Length -gt 140) { $sujet = $sujet.Substring(0, 137) + '...' }
    $sujet = $sujet -replace '[\r\n]', ' '

    $corps = "Routine  : $Routine`nResultat : $Resultat`nFin (NC) : $stamp`nPreuve   : $Preuve"
    if ($Alerte) { $corps += "`nAlerte   : $Alerte" }

    # --- LE POINT CENTRAL : l'auteur du commit EST la routine ---------------
    $out = Invoke-Git -Repo $Repo -GitArgs @(
        '-c', "user.name=$Routine", '-c', "user.email=$MAIL",
        'commit', '-q', '-m', $sujet, '-m', $corps
    )

    $hash = (Invoke-Git -Repo $Repo -GitArgs @('rev-parse', '--short', 'HEAD')) -join ''
    if ($hash) {
        # $script: obligatoire : sans lui, PowerShell crée une variable locale à la
        # fonction et le champ `commits` du journal ressort vide (constaté au 1er test).
        $script:commits         += "$Etiquette=$($hash.Trim())"
        $script:fichiersTouches += $modifies
        Write-Host "  [$Etiquette] commit $($hash.Trim()) — $($modifies.Count) fichier(s), auteur '$Routine'"
    } else {
        Write-Warning "$Etiquette : le commit n'a pas abouti. $out"
    }

    # Le dépôt de suivi n'a pas de remote : pas de push, c'est attendu.
    $remote = Invoke-Git -Repo $Repo -GitArgs @('remote')
    if ($remote) {
        if (Push-Verifie -Repo $Repo -Etiquette $Etiquette) { Write-Host "  [$Etiquette] pousse sur origin" }
    }
}

Write-Host "trace-routine — $Routine ($Resultat) — $stamp NC"

# ---------------------------------------------------------------------------
# 0. Miroir des DÉFINITIONS de routines (ajouté le 24/08/2026, demande de JM).
#
#    Les fichiers SKILL.md des tâches planifiées ne sont dans aucun dépôt : une
#    consigne pouvait donc dériver du réel sans date ni auteur. Trois dérives
#    déjà payées (détail dans l'en-tête de sync-routines.ps1).
#
#    C'est fait ICI, avant le commit, et pas dans une routine dédiée : toute
#    routine qui clôture emporte le miroir avec elle. Une synchro qui dépendrait
#    d'une routine de plus retomberait dans le mode de défaillance dominant —
#    la routine qui meurt au premier appel d'outil et n'écrit rien.
#
#    Le commit portera le nom de la routine qui passait là. C'est une
#    approximation assumée : les définitions sont éditées par des sessions
#    Claude, pas par les routines elles-mêmes. Ce qu'on gagne, c'est l'HISTORIQUE
#    du texte et sa date — ce qui manquait totalement.
# ---------------------------------------------------------------------------
$sync = Join-Path $REPO_PROJET 'automation-agent\sync-routines.ps1'
if (Test-Path $sync) {
    try { & $sync -Silencieux | Out-Null }
    catch { Write-Warning "sync-routines a echoue (les definitions ne sont pas a jour) : $_" }
} else {
    Write-Warning "sync-routines.ps1 introuvable : les definitions de routines ne sont pas versionnees."
}

Commit-Repo -Repo $REPO_SUIVI  -Etiquette 'suivi'
Commit-Repo -Repo $REPO_PROJET -Etiquette 'projet' -ExcludeJournal

# ---------------------------------------------------------------------------
# 2. Ligne de journal — enrichie de la liste des fichiers réellement touchés.
# ---------------------------------------------------------------------------
if ($pushEchecs.Count -gt 0) {
    $prefixe = "PUSH EN ECHEC (" + ($pushEchecs -join ' | ') + ")"
    $Alerte  = if ([string]::IsNullOrWhiteSpace($Alerte)) { $prefixe } else { "$prefixe ; $Alerte" }
}

$ligne = [ordered]@{
    routine     = $Routine
    fin_nc      = $finNC
    resultat    = $Resultat
    effet       = $Effet
    preuve      = $Preuve
    alerte      = if ([string]::IsNullOrWhiteSpace($Alerte)) { $null } else { $Alerte }
    fichiers    = @($fichiersTouches | Sort-Object -Unique)
    commits     = @($commits)
    push_echecs = @($pushEchecs)
}

$json = ($ligne | ConvertTo-Json -Compress -Depth 4)

# UTF-8 sans BOM, saut de ligne LF : le journal se lit ligne à ligne.
[System.IO.File]::AppendAllText($JOURNAL, $json + "`n", (New-Object System.Text.UTF8Encoding($false)))

Invoke-Git -Repo $REPO_PROJET -GitArgs @('add', '--', 'automation-agent/journal-executions.jsonl') | Out-Null
Invoke-Git -Repo $REPO_PROJET -GitArgs @(
    '-c', "user.name=$Routine", '-c', "user.email=$MAIL",
    'commit', '-q', '-m', "journal: $Routine - $Resultat"
) | Out-Null
$echecsAvantJournal = $pushEchecs.Count
if (Push-Verifie -Repo $REPO_PROJET -Etiquette 'journal') {
    Write-Host "  [journal] ligne ajoutee et poussee"
} else {
    # Ce dernier échec ne peut plus figurer dans la ligne déjà écrite : il passe
    # par la sortie et le code de retour ci-dessous.
    Write-Warning "[journal] ligne ajoutee en LOCAL seulement : $($pushEchecs[$echecsAvantJournal..($pushEchecs.Count - 1)] -join ' | ')"
}

# ---------------------------------------------------------------------------
# Regeneration du CALENDRIER LISIBLE (demande de Jean-Michel du 15/09/2026 :
# « ton calendrier des publications doit etre sauvegarde en dur sur le cloud,
# il y a trop de doute a ce niveau »).
# Fait ICI, comme le verrou, parce que trace-routine est le seul point de passage
# obligatoire de TOUTES les routines : le document Word et le Markdown deposes sur
# OneDrive ne peuvent donc jamais diverger du registre publications.json.
# Un echec ici n'est jamais bloquant : la routine a deja fait son travail.
# ---------------------------------------------------------------------------
$CAL = Join-Path $PSScriptRoot 'calendrier-lisible.py'
if (Test-Path $CAL) {
    try {
        $null = & python $CAL 16 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [calendrier] document OneDrive regenere (Word + Markdown)"
        } else {
            Write-Warning "Le calendrier lisible n'a pas pu etre regenere (code $LASTEXITCODE) — document OneDrive possiblement perime."
        }
    } catch {
        Write-Warning "Le calendrier lisible n'a pas pu etre regenere : $_"
    }
} else {
    Write-Warning "calendrier-lisible.py introuvable — document OneDrive non regenere."
}

# ---------------------------------------------------------------------------
# Liberation du verrou d'exclusion mutuelle (regle Jean-Michel du 12/09/2026 :
# jamais deux routines en parallele, 15 minutes d'ecart minimum, ordre respecte
# meme quand le PC est allume tard et que les creneaux manques sont rejoues).
# Fait ICI parce que trace-routine est le seul point de passage obligatoire de
# TOUTES les routines : une liberation oubliee bloquerait toutes les suivantes.
# ---------------------------------------------------------------------------
$VERROU = Join-Path $PSScriptRoot 'verrou.ps1'
if (Test-Path $VERROU) {
    try {
        & $VERROU -Liberer -Routine $Routine | ForEach-Object { Write-Host "  [verrou] $_" }
    } catch {
        Write-Warning "Le verrou n'a pas pu etre libere : $_"
        Write-Warning "Le liberer a la main : & '$VERROU' -Liberer -Routine '$Routine'"
    }
} else {
    Write-Warning "verrou.ps1 introuvable — verrou non libere."
}

if ($pushEchecs.Count -gt 0) {
    Write-Host ""
    Write-Host "PUSH: ECHEC — rien de ce que cette routine a commite n'est garanti sur GitHub."
    $pushEchecs | ForEach-Object { Write-Host "  - $_" }
    Write-Host "  Les workflows GitHub (publication, bascules) ne voient PAS ces commits. A signaler"
    Write-Host "  dans le brouillon Gmail et a resoudre a la main (git pull, resoudre le conflit, git push)."
    exit 4
}

Write-Host "OK — $($ligne.fichiers.Count) fichier(s) tracé(s)."
if ($ligne.fichiers.Count -eq 0) {
    Write-Host "     (aucun fichier modifie : normal pour un resultat 'rien-a-faire')"
}
