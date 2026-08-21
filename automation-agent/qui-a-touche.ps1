<#
.SYNOPSIS
    Répond à : « quelle routine a travaillé sur ce fichier, et quand ? »

.DESCRIPTION
    Interroge les deux dépôts (suivi + projet) et le journal d'exécutions, et
    présente l'historique d'un fichier : chaque passage, la routine qui l'a
    signé, la date, et ce qui a changé.

    Sans argument, dresse le tableau de bord : dernier passage de chaque
    routine, et alerte sur celles qui n'ont rien écrit depuis trop longtemps
    (le silence est le signal — une routine morte au premier appel d'outil
    n'écrit pas sa ligne).

.EXAMPLE
    .\qui-a-touche.ps1 SUIVI-AUTOMATISATION.md
    .\qui-a-touche.ps1 mardi.json
    .\qui-a-touche.ps1 -Routine perfeco-rappel-quotidien
    .\qui-a-touche.ps1                      # vue d'ensemble
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)][string] $Fichier,
    [string] $Routine,
    [int]    $Limite = 20
)

$ErrorActionPreference = 'SilentlyContinue'

$REPOS = @(
    @{ Nom = 'suivi';  Chemin = 'C:\Users\jmbla\OneDrive\Documents\claude IA' }
    @{ Nom = 'projet'; Chemin = 'C:\Projets\perfecoconsulting' }
)
$JOURNAL = 'C:\Projets\perfecoconsulting\automation-agent\journal-executions.jsonl'

function Write-Titre { param([string] $T) Write-Host ""; Write-Host $T -ForegroundColor Cyan; Write-Host ('-' * $T.Length) -ForegroundColor DarkGray }

# ---------------------------------------------------------------------------
# Cas 1 — historique d'un fichier
# ---------------------------------------------------------------------------
if ($Fichier) {
    Write-Titre "Historique de : $Fichier"
    $trouve = $false

    foreach ($r in $REPOS) {
        if (-not (Test-Path (Join-Path $r.Chemin '.git'))) { continue }
        Push-Location $r.Chemin
        try {
            # --follow suit les renommages ; le glob attrape un nom donné sans chemin.
            $lignes = & git log --follow --format="%h`t%an`t%ad`t%s" --date=format:"%d/%m/%Y %H:%M" `
                        -n $Limite -- "*$Fichier" 2>$null
            if ($lignes) {
                $trouve = $true
                Write-Host ""
                Write-Host "  depot $($r.Nom) :" -ForegroundColor Yellow
                foreach ($l in $lignes) {
                    $p = $l -split "`t"
                    Write-Host ("    {0}  {1,-32} {2}" -f $p[2], $p[1], $p[0]) -ForegroundColor Gray
                    Write-Host ("        {0}" -f $p[3])
                }
            }
        } finally { Pop-Location }
    }

    # Le journal couvre aussi les fichiers non versionnés (scripts à secrets).
    if (Test-Path $JOURNAL) {
        $hits = Get-Content $JOURNAL -Encoding UTF8 | ForEach-Object {
            try { $o = $_ | ConvertFrom-Json } catch { return }
            if ($o.fichiers -and ($o.fichiers -join ' ') -match [regex]::Escape($Fichier)) { $o }
        } | Select-Object -Last $Limite
        if ($hits) {
            $trouve = $true
            Write-Host ""
            Write-Host "  journal d'executions :" -ForegroundColor Yellow
            foreach ($h in $hits) {
                Write-Host ("    {0}  {1,-32} [{2}]" -f $h.fin_nc, $h.routine, $h.resultat) -ForegroundColor Gray
                Write-Host ("        {0}" -f $h.effet)
            }
        }
    }

    if (-not $trouve) {
        Write-Host "  Aucune trace." -ForegroundColor DarkYellow
        Write-Host "  Soit le fichier n'a jamais ete touche depuis la mise en place du"
        Write-Host "  versionning (21/08/2026), soit son nom est different."
    }
    return
}

# ---------------------------------------------------------------------------
# Cas 2 — tout ce qu'une routine a touché
# ---------------------------------------------------------------------------
if ($Routine) {
    Write-Titre "Passages de : $Routine"
    foreach ($r in $REPOS) {
        if (-not (Test-Path (Join-Path $r.Chemin '.git'))) { continue }
        Push-Location $r.Chemin
        try {
            $lignes = & git log --author="$Routine" --format="%h`t%ad`t%s" `
                        --date=format:"%d/%m/%Y %H:%M" -n $Limite 2>$null
            if ($lignes) {
                Write-Host ""
                Write-Host "  depot $($r.Nom) :" -ForegroundColor Yellow
                foreach ($l in $lignes) {
                    $p = $l -split "`t"
                    Write-Host ("    {0}  {1}" -f $p[1], $p[0]) -ForegroundColor Gray
                    Write-Host ("        {0}" -f $p[2])
                }
            }
        } finally { Pop-Location }
    }
    return
}

# ---------------------------------------------------------------------------
# Cas 3 — vue d'ensemble : dernier passage de chaque routine
# ---------------------------------------------------------------------------
Write-Titre "Dernier passage de chaque routine (source : journal d'executions)"

if (-not (Test-Path $JOURNAL)) { Write-Host "  Journal introuvable."; return }

$nowNC = [System.DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(11))

$parRoutine = Get-Content $JOURNAL -Encoding UTF8 | ForEach-Object {
    try { $_ | ConvertFrom-Json } catch { $null }
} | Where-Object { $_ -and $_.routine } | Group-Object routine

Write-Host ""
Write-Host ("  {0,-34} {1,-18} {2,-14} {3}" -f 'ROUTINE', 'DERNIERE FIN (NC)', 'RESULTAT', 'AGE') -ForegroundColor DarkGray

foreach ($g in ($parRoutine | Sort-Object Name)) {
    $last = $g.Group | Sort-Object fin_nc | Select-Object -Last 1
    $age  = ''
    $couleur = 'Gray'
    try {
        $d = [System.DateTimeOffset]::Parse($last.fin_nc)
        $j = [int]($nowNC - $d).TotalDays
        $h = [int]($nowNC - $d).TotalHours
        $age = if ($h -lt 24) { "$h h" } else { "$j j" }
        if ($j -ge 8) { $couleur = 'Red' }   # une hebdo muette depuis 8 j = suspect
        elseif ($last.resultat -eq 'echec') { $couleur = 'Red' }
    } catch { }

    Write-Host ("  {0,-34} {1,-18} {2,-14} {3}" -f `
        $g.Name, ($last.fin_nc -replace 'T', ' ' -replace '\+11:00', ''), $last.resultat, $age) -ForegroundColor $couleur
}

Write-Host ""
Write-Host "  Rouge = dernier passage en echec, ou silence depuis 8 jours ou plus." -ForegroundColor DarkGray
Write-Host "  Rappel : l'ABSENCE de ligne est le signal. Une routine qui meurt a son" -ForegroundColor DarkGray
Write-Host "  premier appel d'outil (jeton expire) n'ecrit rien et ne peut pas alerter." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Detail d'un fichier   : .\qui-a-touche.ps1 SUIVI-AUTOMATISATION.md" -ForegroundColor DarkGray
Write-Host "  Detail d'une routine  : .\qui-a-touche.ps1 -Routine mardi-carrousel-creation" -ForegroundColor DarkGray
