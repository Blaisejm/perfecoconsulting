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

function Invoke-Git {
    param([string] $Repo, [string[]] $GitArgs)
    Push-Location $Repo
    try   { & git @GitArgs 2>&1 }
    catch { Write-Warning "git $($GitArgs -join ' ') a echoue dans $Repo : $_"; $null }
    finally { Pop-Location }
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
        $commits += "$Etiquette=$($hash.Trim())"
        $script:fichiersTouches += $modifies
        Write-Host "  [$Etiquette] commit $($hash.Trim()) — $($modifies.Count) fichier(s), auteur '$Routine'"
    } else {
        Write-Warning "$Etiquette : le commit n'a pas abouti. $out"
    }

    # Push silencieux : le dépôt de suivi n'a pas de remote, c'est attendu.
    $remote = Invoke-Git -Repo $Repo -GitArgs @('remote')
    if ($remote) { Invoke-Git -Repo $Repo -GitArgs @('push', '-q', 'origin', 'HEAD') | Out-Null }
}

Write-Host "trace-routine — $Routine ($Resultat) — $stamp NC"

Commit-Repo -Repo $REPO_SUIVI  -Etiquette 'suivi'
Commit-Repo -Repo $REPO_PROJET -Etiquette 'projet' -ExcludeJournal

# ---------------------------------------------------------------------------
# 2. Ligne de journal — enrichie de la liste des fichiers réellement touchés.
# ---------------------------------------------------------------------------
$ligne = [ordered]@{
    routine  = $Routine
    fin_nc   = $finNC
    resultat = $Resultat
    effet    = $Effet
    preuve   = $Preuve
    alerte   = if ([string]::IsNullOrWhiteSpace($Alerte)) { $null } else { $Alerte }
    fichiers = @($fichiersTouches | Sort-Object -Unique)
    commits  = @($commits)
}

$json = ($ligne | ConvertTo-Json -Compress -Depth 4)

# UTF-8 sans BOM, saut de ligne LF : le journal se lit ligne à ligne.
[System.IO.File]::AppendAllText($JOURNAL, $json + "`n", (New-Object System.Text.UTF8Encoding($false)))

Push-Location $REPO_PROJET
try {
    & git add -- 'automation-agent/journal-executions.jsonl' 2>&1 | Out-Null
    & git -c "user.name=$Routine" -c "user.email=$MAIL" `
        commit -q -m "journal: $Routine - $Resultat" 2>&1 | Out-Null
    & git push -q origin HEAD 2>&1 | Out-Null
    Write-Host "  [journal] ligne ajoutee et poussee"
} catch {
    Write-Warning "Le journal n'a pas pu etre pousse : $_"
} finally { Pop-Location }

Write-Host "OK — $($ligne.fichiers.Count) fichier(s) tracé(s)."
if ($ligne.fichiers.Count -eq 0) {
    Write-Host "     (aucun fichier modifie : normal pour un resultat 'rien-a-faire')"
}
