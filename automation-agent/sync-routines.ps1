<#
.SYNOPSIS
    Versionne les DÉFINITIONS des routines (les fichiers SKILL.md des tâches
    planifiées) dans le dépôt de suivi, et signale ce qui a changé.

.DESCRIPTION
    Demandé par Jean-Michel le 24/08/2026.

    LE TROU QUE CE SCRIPT FERME
    Les définitions de routines vivent dans
        C:\Users\jmbla\.claude\scheduled-tasks\<nom>\SKILL.md
    qui n'est un dépôt git d'AUCUNE sorte. Conséquence : la consigne d'une
    routine pouvait dériver du réel sans trace, sans date et sans auteur.
    Trois dérives déjà payées, toutes de ce même mécanisme :

      21/08  la consigne affirmait « le samedi est suspendu » alors que son cron
             avait été réactivé le 18/08 — le workflow tournait sans surveillance.
      18/08  publish-lundi-facebook.yml supprimé du dépôt le 12/08 mais toujours
             interrogé : l'API renvoyait son vieux run en `success`, faux
             « tout va bien » sur un workflow inexistant.
      24/08  2 workflows actifs sur 9 jamais ajoutés à la liste surveillée, dont
             le filet indépendant lui-même (check-preparation-contenu.yml).

    Aucune de ces dérives n'était visible : rien ne permettait de comparer la
    consigne d'aujourd'hui à celle d'hier. C'est exactement le manque que
    trace-routine.ps1 a comblé pour les FICHIERS DE TRAVAIL le 21/08 ; ce
    script-ci l'étend aux CONSIGNES ELLES-MÊMES.

    POURQUOI LE DÉPÔT DE SUIVI ET PAS perfecoconsulting
    perfecoconsulting est PUBLIC (vérifié via l'API GitHub le 24/08/2026 :
    visibility=public). Les définitions ne contiennent aucun identifiant — c'est
    vérifié — mais elles portent tout l'interne : arbitrages éditoriaux, noms de
    prospects, adresses, tactique commerciale. Elles vont donc dans
    « OneDrive\Documents\claude IA », dépôt SANS REMOTE, sauvegardé par OneDrive.

    Le script REFUSE d'écrire dans un dépôt qui a un remote, sauf
    -AutoriserDepotDistant. C'est volontaire : le jour où quelqu'un pointera ce
    script sur le dépôt public, il faudra que ce soit un choix explicite.

.PARAMETER Depot
    Dépôt de destination. Défaut : le dépôt de suivi.

.PARAMETER Silencieux
    N'affiche que les changements (pour l'appel automatique par trace-routine).

.PARAMETER AutoriserDepotDistant
    Lève le garde-fou ci-dessus. À n'utiliser qu'en connaissance de cause.

.OUTPUTS
    Un objet : Nouveaux, Modifies, Supprimes, Inchanges, Total.
    Le script ne commite RIEN — c'est trace-routine.ps1 qui commite, pour que
    le passage porte le nom de la routine qui l'a provoqué.
#>

[CmdletBinding()]
param(
    [string] $Depot = 'C:\Users\jmbla\OneDrive\Documents\claude IA',
    [switch] $Silencieux,
    [switch] $AutoriserDepotDistant
)

$ErrorActionPreference = 'Stop'

$SOURCE = 'C:\Users\jmbla\.claude\scheduled-tasks'
$DEST   = Join-Path $Depot 'routines'

function Ecrire { param([string] $Texte) if (-not $Silencieux) { Write-Host $Texte } }

if (-not (Test-Path $SOURCE)) { throw "Source introuvable : $SOURCE" }
if (-not (Test-Path (Join-Path $Depot '.git'))) { throw "Pas un depot git : $Depot" }

# --- Garde-fou : jamais de definitions dans un depot public par accident ------
Push-Location $Depot
try { $remote = (& git remote 2>$null) } finally { Pop-Location }
if ($remote -and -not $AutoriserDepotDistant) {
    throw ("Le depot '$Depot' a un remote ($($remote -join ', ')). " +
           "Les definitions de routines portent l'interne PerfEco et ne doivent pas " +
           "partir sur un remote sans decision explicite. Relancer avec " +
           "-AutoriserDepotDistant si c'est bien l'intention.")
}

if (-not (Test-Path $DEST)) { New-Item -ItemType Directory -Path $DEST -Force | Out-Null }

# --- 1. Miroir des definitions ------------------------------------------------
# Les dossiers _backup-* sont des sauvegardes ponctuelles prises par d'anciennes
# sessions : les versionner ferait doublon avec l'historique git, qui est
# precisement ce qu'on met en place.
$routines = Get-ChildItem -Path $SOURCE -Directory |
            Where-Object { $_.Name -notlike '_backup*' } |
            Sort-Object Name

$nouveaux = @(); $modifies = @(); $inchanges = @(); $sansSkill = @()
$vues     = @{}

foreach ($r in $routines) {
    $src = Join-Path $r.FullName 'SKILL.md'
    if (-not (Test-Path $src)) { $sansSkill += $r.Name; continue }

    $cible = Join-Path $DEST "$($r.Name).SKILL.md"
    $vues["$($r.Name).SKILL.md"] = $true

    if (-not (Test-Path $cible)) {
        Copy-Item $src $cible -Force
        $nouveaux += $r.Name
    }
    else {
        # Comparaison sur le contenu, pas sur la date : OneDrive et les copies
        # rafraichissent les horodatages sans que le texte change.
        $hSrc = (Get-FileHash $src   -Algorithm SHA256).Hash
        $hDst = (Get-FileHash $cible -Algorithm SHA256).Hash
        if ($hSrc -ne $hDst) { Copy-Item $src $cible -Force; $modifies += $r.Name }
        else                 { $inchanges += $r.Name }
    }
}

# --- 2. Routines disparues : on les retire du miroir --------------------------
# git garde leur histoire ; les laisser ici recreerait le faux « tout va bien »
# de publish-lundi-facebook.yml, ou une consigne morte reste consultable comme
# si elle etait vivante.
$supprimes = @()
Get-ChildItem -Path $DEST -Filter '*.SKILL.md' -File | ForEach-Object {
    if (-not $vues.ContainsKey($_.Name)) {
        Remove-Item $_.FullName -Force
        $supprimes += ($_.Name -replace '\.SKILL\.md$', '')
    }
}

# --- 3. Index lisible ---------------------------------------------------------
$nowNC = [System.DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(11))
$lignes = New-Object System.Collections.Generic.List[string]
$lignes.Add('# Définitions de routines — miroir versionné')
$lignes.Add('')
$lignes.Add("Généré par ``automation-agent/sync-routines.ps1`` le $($nowNC.ToString('dd/MM/yyyy HH:mm')) NC.")
$lignes.Add('')
$lignes.Add('**Ce dossier est un miroir, pas la source.** La source exécutée par Cowork reste')
$lignes.Add('`C:\Users\jmbla\.claude\scheduled-tasks\<nom>\SKILL.md`. Modifier un fichier ici ne')
$lignes.Add('change rien au comportement d''une routine — et sera écrasé à la prochaine synchro.')
$lignes.Add('Ce miroir sert à une seule chose : pouvoir répondre à « qu''est-ce que cette consigne')
$lignes.Add('disait la semaine dernière, et qui l''a changée ». Voir l''en-tête du script pour les')
$lignes.Add('trois dérives qui ont motivé sa création.')
$lignes.Add('')
$lignes.Add('```powershell')
$lignes.Add('git -C "C:\Users\jmbla\OneDrive\Documents\claude IA" log --follow -p -- routines/<nom>.SKILL.md')
$lignes.Add('```')
$lignes.Add('')
$lignes.Add("| Routine | Description | Taille |")
$lignes.Add("|---|---|---|")

foreach ($r in $routines) {
    $f = Join-Path $DEST "$($r.Name).SKILL.md"
    if (-not (Test-Path $f)) { continue }
    $desc = ''
    foreach ($l in (Get-Content $f -Encoding UTF8 -TotalCount 12)) {
        if ($l -match '^description:\s*(.+)$') { $desc = $Matches[1].Trim().Trim('"'); break }
    }
    if ($desc.Length -gt 150) { $desc = $desc.Substring(0, 147) + '...' }
    $desc = $desc -replace '\|', '\|'
    $ko = [math]::Round((Get-Item $f).Length / 1KB, 1)
    $lignes.Add("| ``$($r.Name)`` | $desc | $ko ko |")
}

$lignes.Add('')
$lignes.Add("**$($routines.Count) routines**, dont $($sansSkill.Count) sans fichier SKILL.md.")
if ($sansSkill.Count -gt 0) {
    $lignes.Add('')
    $lignes.Add('Sans SKILL.md (dossier vide ou définition perdue) : ' +
                (($sansSkill | ForEach-Object { "``$_``" }) -join ', '))
}

$index = Join-Path $DEST 'INVENTAIRE.md'
[System.IO.File]::WriteAllText($index, (($lignes -join "`n") + "`n"),
                               (New-Object System.Text.UTF8Encoding($false)))

# --- 4. Compte rendu ----------------------------------------------------------
if ($nouveaux.Count -or $modifies.Count -or $supprimes.Count) {
    Write-Host "sync-routines : $($nouveaux.Count) nouvelle(s), $($modifies.Count) modifiee(s), $($supprimes.Count) supprimee(s)"
    foreach ($n in $nouveaux)  { Write-Host "  + $n" }
    foreach ($m in $modifies)  { Write-Host "  ~ $m  (definition changee depuis la derniere synchro)" }
    foreach ($s in $supprimes) { Write-Host "  - $s  (routine disparue, historique conserve dans git)" }
} else {
    Ecrire "sync-routines : $($inchanges.Count) definitions, aucune modification."
}
if ($sansSkill.Count -gt 0) {
    Write-Warning ("Dossier(s) sans SKILL.md : " + ($sansSkill -join ', '))
}

[pscustomobject]@{
    Nouveaux  = $nouveaux
    Modifies  = $modifies
    Supprimes = $supprimes
    Inchanges = $inchanges.Count
    Total     = $routines.Count
}
