<#
.SYNOPSIS
    Verrou d'exclusion mutuelle + ordre de passage pour les routines PerfEco.

.DESCRIPTION
    Regle posee par Jean-Michel le 12/09/2026 :
    « les routines ne tournent pas en meme temps, il faut etablir un ordre logique
      et les faire tourner l'une apres l'autre a 15 minutes d'intervalle.
      En cas d'ouverture de mon ordinateur apres 7h, l'ordonnancement est respecte
      et les routines respectent la cadence definie. En aucun cas les routines ne
      tournent en parallele ou en meme temps. »

    POURQUOI CE SCRIPT EXISTE. Le cron dit QUAND declencher, il ne dit rien sur ce
    qui se passe au reveil de la machine. Constate le 12/09/2026, PC allume vers
    11h30 : perfeco-verif-github-actions a 11h47, perfeco-rappel-quotidien a 11h57
    (+9 min), mercredi-creation a 12h08 (+11 min). Deux defauts :
      1. l'ecart tombe sous 15 minutes et les executions se recouvrent ;
      2. l'ORDRE est arbitraire — la verification (rang 7) est passee AVANT la
         production (rang 3). C'est ce qui a produit le doublon du 12/09, le filet
         quotidien ayant produit le contenu que mercredi-creation allait ecrire.

    Le verrou vit HORS DU DEPOT (dans %USERPROFILE%\.claude) : c'est un etat local
    de concurrence, le pousser sur git creerait des conflits a chaque passage.

.EXAMPLE
    # En TOUTE PREMIERE instruction de la routine, avant tout autre appel d'outil :
    & 'C:\Projets\perfecoconsulting\automation-agent\verrou.ps1' -Prendre -Routine 'mercredi-creation'

    # Liberation : faite automatiquement par trace-routine.ps1 en fin de routine.
    & 'C:\Projets\perfecoconsulting\automation-agent\verrou.ps1' -Liberer -Routine 'mercredi-creation'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Routine,
    [switch]$Prendre,
    [switch]$Liberer,
    [switch]$Etat,
    # Cadence imposee entre la fin d'une routine et le debut de la suivante.
    [int]$EspacementMinutes = 15,
    # Au-dela, un verrou est considere abandonne (routine morte sans liberer).
    [int]$PerimeMinutes = 45,
    # Attente bloquante maximale dans UN appel. Volontairement < 10 min : l'outil
    # PowerShell de l'agent coupe a 10 minutes. Au-dela, le script rend la main
    # avec ATTENDRE et c'est la routine qui rappelle.
    [int]$AttenteBloquanteMax = 8,
    # Nombre de minutes au-dela duquel on passe en force plutot que de ne jamais tourner.
    [int]$AbandonApresMinutes = 75
)

$ErrorActionPreference = 'Stop'

# --- Ordre de passage (pipeline) -------------------------------------------
# veille externe -> production -> filet et bascule -> rapport -> verification
$RANGS = @{
    'veille-marches-publics-nc'   = 1
    'perfeco-verif-linkedin-mdp'  = 2
    'mardi-carrousel-creation'    = 3
    'mercredi-creation'           = 3
    'perfeco-rappel-quotidien'    = 4
    'perfeco-rapport-dimanche'    = 5
    'perfeco-revue-semestrielle'  = 6
    'perfeco-verif-github-actions' = 7
}

$FICHIER = Join-Path $env:USERPROFILE '.claude\verrou-routines.json'

function Get-Etat {
    if (-not (Test-Path $FICHIER)) {
        return [pscustomobject]@{ detenteur = $null; pris_a = $null; battement = $null; derniere_liberation = $null; attente = @() }
    }
    $brut = [System.IO.File]::ReadAllText($FICHIER, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($brut)) {
        return [pscustomobject]@{ detenteur = $null; pris_a = $null; battement = $null; derniere_liberation = $null; attente = @() }
    }
    # ConvertFrom-Json rend un PSCustomObject ; ne jamais l'emballer dans @( ).
    return ($brut | ConvertFrom-Json)
}

function Set-Etat($e) {
    $dossier = Split-Path $FICHIER -Parent
    if (-not (Test-Path $dossier)) { New-Item -ItemType Directory -Force -Path $dossier | Out-Null }
    $json = $e | ConvertTo-Json -Depth 6
    # UTF-8 SANS BOM : un BOM casse toute relecture par un autre outil.
    [System.IO.File]::WriteAllText($FICHIER, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-Horodatage { (Get-Date).ToString('o') }

function ConvertTo-Date($s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    try { return [datetime]::Parse($s) } catch { return $null }
}

function Get-Rang($nom) {
    if ($RANGS.ContainsKey($nom)) { return $RANGS[$nom] }
    return 99   # routine inconnue : passe en dernier, jamais bloquante pour les autres
}

# --- ETAT -------------------------------------------------------------------
if ($Etat) {
    $e = Get-Etat
    Write-Output "Verrou   : $FICHIER"
    if ($e.detenteur) {
        $age = [int]((Get-Date) - (ConvertTo-Date $e.battement)).TotalMinutes
        Write-Output "DETENU par '$($e.detenteur)' depuis $($e.pris_a) (battement il y a $age min)"
    } else {
        Write-Output "LIBRE"
    }
    if ($e.derniere_liberation) { Write-Output "Derniere liberation : $($e.derniere_liberation)" }
    if ($e.attente -and $e.attente.Count -gt 0) {
        Write-Output "En attente :"
        foreach ($a in $e.attente) { Write-Output ("  rang {0}  {1}  (depuis {2})" -f $a.rang, $a.routine, $a.depuis) }
    }
    exit 0
}

# --- LIBERER ----------------------------------------------------------------
if ($Liberer) {
    $e = Get-Etat
    if ($e.detenteur -and $e.detenteur -ne $Routine) {
        Write-Output "AVERTISSEMENT : le verrou est detenu par '$($e.detenteur)', pas par '$Routine'. Liberation quand meme."
    }
    $e.detenteur = $null
    $e.pris_a = $null
    $e.battement = $null
    $e.derniere_liberation = Get-Horodatage
    $e.attente = @($e.attente | Where-Object { $_.routine -ne $Routine })
    Set-Etat $e
    Write-Output "LIBERE : $Routine a $((Get-Date).ToString('HH:mm')) NC"
    exit 0
}

# --- PRENDRE ----------------------------------------------------------------
if (-not $Prendre) { throw "Preciser -Prendre, -Liberer ou -Etat." }

$monRang = Get-Rang $Routine
$debutAttente = Get-Date

# Inscription dans la file d'attente : c'est ce qui permet a une routine de rang
# inferieur, declenchee en meme temps au reveil, d'obtenir la priorite.
$e = Get-Etat
$e.attente = @($e.attente | Where-Object { $_.routine -ne $Routine })
$e.attente += [pscustomobject]@{ routine = $Routine; rang = $monRang; depuis = (Get-Horodatage) }
Set-Etat $e

# Laisse 20 s aux routines declenchees dans la meme rafale pour s'inscrire aussi,
# sinon la premiere arrivee passe toujours, quel que soit son rang.
Start-Sleep -Seconds 20

$finBloquante = (Get-Date).AddMinutes($AttenteBloquanteMax)

while ($true) {
    $e = Get-Etat
    $maintenant = Get-Date
    $motif = $null

    # 1. Le verrou est-il detenu par une routine encore vivante ?
    if ($e.detenteur -and $e.detenteur -ne $Routine) {
        $batt = ConvertTo-Date $e.battement
        if ($batt -and ($maintenant - $batt).TotalMinutes -lt $PerimeMinutes) {
            $motif = "'$($e.detenteur)' tourne encore (depuis $([int]($maintenant - $batt).TotalMinutes) min)"
        } else {
            Write-Output "Verrou perime de '$($e.detenteur)' (aucun battement depuis plus de $PerimeMinutes min) : repris."
            $e.detenteur = $null
            Set-Etat $e
        }
    }

    # 2. Une routine de rang STRICTEMENT inferieur attend-elle son tour ?
    if (-not $motif) {
        $prioritaire = $e.attente |
            Where-Object { $_.routine -ne $Routine -and $_.rang -lt $monRang } |
            Sort-Object rang | Select-Object -First 1
        if ($prioritaire) {
            $motif = "'$($prioritaire.routine)' (rang $($prioritaire.rang)) passe avant '$Routine' (rang $monRang)"
        }
    }

    # 3. La cadence de 15 minutes depuis la derniere liberation est-elle tenue ?
    if (-not $motif -and $e.derniere_liberation) {
        $lib = ConvertTo-Date $e.derniere_liberation
        if ($lib) {
            $ecoule = ($maintenant - $lib).TotalMinutes
            if ($ecoule -lt $EspacementMinutes) {
                $motif = "cadence : $([math]::Round($EspacementMinutes - $ecoule)) min a attendre depuis la derniere routine"
            }
        }
    }

    if (-not $motif) {
        $e.detenteur = $Routine
        $e.pris_a = Get-Horodatage
        $e.battement = Get-Horodatage
        $e.attente = @($e.attente | Where-Object { $_.routine -ne $Routine })
        Set-Etat $e
        $attendu = [int]((Get-Date) - $debutAttente).TotalMinutes
        Write-Output "LIBRE : verrou pris par '$Routine' (rang $monRang) a $((Get-Date).ToString('HH:mm')) NC apres $attendu min d'attente."
        Write-Output "Poursuivre la routine normalement. Le verrou sera libere par trace-routine.ps1."
        exit 0
    }

    # Garde-fou : mieux vaut tourner en retard que jamais.
    if (((Get-Date) - $debutAttente).TotalMinutes -ge $AbandonApresMinutes) {
        $e.detenteur = $Routine
        $e.pris_a = Get-Horodatage
        $e.battement = Get-Horodatage
        $e.attente = @($e.attente | Where-Object { $_.routine -ne $Routine })
        Set-Etat $e
        Write-Output "FORCE : $AbandonApresMinutes min d'attente depassees ($motif). Verrou pris quand meme."
        Write-Output "SIGNALER CE PASSAGE EN FORCE DANS LE BROUILLON GMAIL ET DANS -Alerte."
        exit 0
    }

    if ((Get-Date) -ge $finBloquante) {
        Write-Output "ATTENDRE : $motif"
        Write-Output "Rappeler ce script a l'identique dans 5 minutes. Ne RIEN faire d'autre entre-temps."
        exit 10
    }

    Start-Sleep -Seconds 45
}
