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

    REFONTE DU 21/09/2026 — le verrou ne tenait pas, et pour trois raisons
    independantes. Entre le 15 et le 21/09, quatre passages ont ete constates ou
    une routine s'est fait reprendre son verrou EN PLEIN TRAVAIL, ou a fini son
    execution sans protection. Les trois causes sont traitees ici :

      1. HORLOGE. Le meme script rendait l'heure NC en avant-plan et l'heure UTC
         en arriere-plan, soit 11 h d'ecart, sans aucun avertissement. Des
         horodatages incompatibles cohabitaient donc dans le fichier d'etat et
         TOUS les calculs d'age etaient faux. On stocke et on compare desormais
         en UTC ; on n'affiche qu'en NC. Voir la section « HORLOGE ».

      2. ECRITURES CONCURRENTES. Chaque routine lisait le fichier entier, le
         modifiait, puis le reecrivait entier : une routine qui avait lu avant la
         prise d'une autre et reecrivait apres EFFACAIT sa detention. Lire,
         decider et ecrire forment maintenant une operation indivisible, protegee
         par un mutex nomme. Voir la section « ACCES EXCLUSIF ».

      3. ABSENCE DE BATTEMENT. Rien ne rafraichissait le champ 'battement' entre
         la prise et la liberation : une routine longue mais vivante franchissait
         le seuil de peremption et se faisait reprendre son verrou. Un process de
         fond bat desormais pour elle toutes les 2 minutes, et sa seule presence
         interdit toute reprise. Voir la section « BATTEMENT ».

    CONSEQUENCE A CONNAITRE : on ne reprend plus JAMAIS le verrou d'une routine
    dont le batteur est vivant, et le passage en force (-AbandonApresMinutes) ne
    s'applique plus par-dessus un detenteur vivant. Une routine peut donc attendre
    plus longtemps qu'avant. C'est le prix de la garantie demandee — « en aucun
    cas les routines ne tournent en parallele ». Deblocage a la main si besoin :
    -Liberer -Routine '<detenteur>' -Force.

.EXAMPLE
    # En TOUTE PREMIERE instruction de la routine, avant tout autre appel d'outil :
    & 'C:\Projets\perfecoconsulting\automation-agent\verrou.ps1' -Prendre -Routine 'mercredi-creation'

    # Liberation : faite automatiquement par trace-routine.ps1 en fin de routine.
    # Elle arrete aussi le process de battement lance a la prise.
    & 'C:\Projets\perfecoconsulting\automation-agent\verrou.ps1' -Liberer -Routine 'mercredi-creation'

    # Diagnostic : qui detient le verrou, depuis quand, et son batteur est-il vivant ?
    & 'C:\Projets\perfecoconsulting\automation-agent\verrou.ps1' -Etat -Routine 'diagnostic'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Routine,
    [switch]$Prendre,
    [switch]$Liberer,
    [switch]$Etat,
    # Uniquement avec -Liberer : rendre un verrou detenu par une AUTRE routine.
    # Reserve au deblocage manuel ; une routine ne doit jamais l'utiliser.
    [switch]$Force,
    # Cadence imposee entre la fin d'une routine et le debut de la suivante.
    [int]$EspacementMinutes = 15,
    # Au-dela, un verrou est considere abandonne (routine morte sans liberer).
    [int]$PerimeMinutes = 45,
    # Attente bloquante maximale dans UN appel. Volontairement < 10 min : l'outil
    # PowerShell de l'agent coupe a 10 minutes. Au-dela, le script rend la main
    # avec ATTENDRE et c'est la routine qui rappelle.
    [int]$AttenteBloquanteMax = 8,
    # Nombre de minutes au-dela duquel on passe en force plutot que de ne jamais tourner.
    [int]$AbandonApresMinutes = 75,
    # Usage INTERNE : mode batteur. Lance en tache de fond par -Prendre, ce mode
    # rafraichit le champ 'battement' tant que la routine detient le verrou. Une
    # routine ne l'appelle jamais elle-meme.
    [switch]$Battre,
    [int]$IntervalleBattementSecondes = 120,
    # Garde-fou du batteur : il s'arrete de lui-meme au-dela, pour ne jamais
    # devenir un process zombie qui maintiendrait un verrou en vie sans routine.
    # 2 h est large : la routine la plus longue (perfeco-rapport-dimanche) tourne
    # environ 78 min. Si une routine meurt sans se cloturer, le verrou reste donc
    # au pire 2 h + PerimeMinutes avant d'etre repris - c'est le prix d'une
    # garantie stricte de non-parallelisme, et cela se debloque a la main avec
    # -Liberer -Force.
    [int]$BattementMaxHeures = 2
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

# Nom du mutex d'exclusion sur le FICHIER d'etat. Sans prefixe = portee session,
# ce qui suffit : toutes les routines tournent dans la session de Jean-Michel.
$script:MUTEX_NOM = 'PerfEcoVerrouRoutines'

function Get-Prop($o, $n) {
    if ($null -eq $o) { return $null }
    $prop = $o.PSObject.Properties[$n]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

# Normalise TOUJOURS l'etat relu. ConvertFrom-Json rend un PSCustomObject dont les
# proprietes absentes ne peuvent PAS etre creees par simple affectation :
# $e.batteur_pid = 123 leve une erreur si la cle manquait dans le JSON. Un fichier
# ecrit par une version anterieure du script est donc remis en forme ici, ce qui
# rend la mise a jour transparente.
function ConvertTo-Etat($src) {
    # ATTENTION : @($null) ne rend PAS un tableau vide, mais un tableau d'UN
    # element nul. Cette entree fantome survivait a tous les filtres (
    # $null.routine -ne 'X' est vrai) et, plus grave, « $null -lt 99 » vaut $true
    # en PowerShell : le fantome passait donc pour prioritaire sur TOUTES les
    # routines et les aurait bloquees en permanence des que le verrou se liberait.
    # Trouve au test de concurrence du 21/09/2026. D'ou le filtre explicite, qui
    # nettoie aussi les fichiers deja pollues.
    $attente = @(Get-Prop $src 'attente' | Where-Object { $_ -and $_.routine })
    return [pscustomobject]@{
        detenteur           = Get-Prop $src 'detenteur'
        pris_a              = Get-Prop $src 'pris_a'
        battement           = Get-Prop $src 'battement'
        batteur_pid         = Get-Prop $src 'batteur_pid'
        derniere_liberation = Get-Prop $src 'derniere_liberation'
        attente             = $attente
    }
}

function Get-Etat {
    if (-not (Test-Path $FICHIER)) { return (ConvertTo-Etat $null) }
    $brut = [System.IO.File]::ReadAllText($FICHIER, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($brut)) { return (ConvertTo-Etat $null) }
    # ConvertFrom-Json rend un PSCustomObject ; ne jamais l'emballer dans @( ).
    return (ConvertTo-Etat ($brut | ConvertFrom-Json))
}

function Set-Etat($e) {
    $dossier = Split-Path $FICHIER -Parent
    if (-not (Test-Path $dossier)) { New-Item -ItemType Directory -Force -Path $dossier | Out-Null }
    $json = $e | ConvertTo-Json -Depth 6
    # UTF-8 SANS BOM : un BOM casse toute relecture par un autre outil.
    [System.IO.File]::WriteAllText($FICHIER, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# --- ACCES EXCLUSIF AU FICHIER D'ETAT ----------------------------------------
# Ajoute le 21/09/2026, apres qu'une detention a disparu EN COURS d'execution.
#
# Ce qui se passait : chaque routine LISAIT le fichier entier, le modifiait en
# memoire, puis le REECRIVAIT entier. Une routine qui avait lu l'etat avant la
# prise d'une autre, et qui reecrivait apres, effacait purement et simplement la
# detention de cette derniere. Le 21/09, perfeco-rappel-quotidien a ainsi termine
# son execution avec detenteur=null, sa cloture le constatant en toutes lettres
# (« RIEN A LIBERER : aucun detenteur enregistre »). Le verrou n'etait alors plus
# un verrou du tout : n'importe quelle routine pouvait demarrer par-dessus.
#
# Le garde-fou d'appartenance pose le 15/09 ne pouvait rien y faire : il empeche
# de RENDRE le verrou d'autrui, pas de l'ECRASER.
#
# Desormais lire-modifier-ecrire est une seule operation indivisible : tant qu'une
# routine tient le mutex, aucune autre ne peut ni lire ni ecrire l'etat. Et comme
# la DECISION de prendre le verrou se prend elle aussi a l'interieur, plus aucune
# fenetre ne subsiste entre « le verrou est libre » et « le verrou est a moi ».
function Update-Etat {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Transformation,
        [int]$TimeoutSecondes = 30
    )
    $mutex = New-Object System.Threading.Mutex($false, $script:MUTEX_NOM)
    $acquis = $false
    try {
        try {
            $acquis = $mutex.WaitOne([timespan]::FromSeconds($TimeoutSecondes))
        } catch [System.Threading.AbandonedMutexException] {
            # Le process precedent est mort en tenant le mutex : il nous revient.
            # L'etat sur disque reste coherent, l'ecriture etant faite d'un bloc.
            $acquis = $true
        }
        if (-not $acquis) {
            throw "Acces au fichier de verrou impossible apres $TimeoutSecondes s : le mutex '$($script:MUTEX_NOM)' est tenu anormalement longtemps."
        }

        $etat = Get-Etat
        $resultat = & $Transformation $etat
        if ($resultat -and $resultat.ContainsKey('etat') -and $resultat.etat) {
            Set-Etat $resultat.etat
        }
        return $resultat
    } finally {
        if ($acquis) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

# --- BATTEMENT ---------------------------------------------------------------
# Deuxieme cause du defaut, et la plus ancienne : RIEN ne rafraichissait le champ
# 'battement' entre la prise et la liberation. Une routine longue mais vivante
# (mardi-carrousel-creation, perfeco-rapport-dimanche) franchissait donc le seuil
# de peremption et se faisait reprendre son verrou EN PLEIN TRAVAIL - constate les
# 15, 19, 20 et 21/09/2026. C'est precisement « deux routines en parallele ».
#
# Une routine Claude n'est pas un process : chaque appel d'outil en lance un neuf,
# elle ne peut donc pas battre d'elle-meme. -Prendre lance par consequent un
# process de fond discret qui bat pour elle, et qui s'arrete des qu'elle n'est
# plus detentrice.
function Test-BatteurVivant($pidBatteur) {
    if (-not $pidBatteur) { return $false }
    try {
        $proc = Get-Process -Id $pidBatteur -ErrorAction Stop
        # Windows reutilise les PID : on verifie que c'est bien un PowerShell,
        # sinon un verrou abandonne passerait pour vivant.
        return ($proc.ProcessName -like 'powershell*' -or $proc.ProcessName -like 'pwsh*')
    } catch {
        return $false
    }
}

function Start-Batteur($nomRoutine) {
    try {
        $argsBatteur = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $PSCommandPath,
            '-Battre', '-Routine', $nomRoutine,
            '-IntervalleBattementSecondes', $IntervalleBattementSecondes,
            '-BattementMaxHeures', $BattementMaxHeures
        )
        $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $argsBatteur -WindowStyle Hidden -PassThru
        return $proc.Id
    } catch {
        # Un batteur qui ne demarre pas n'est pas bloquant : on retombe sur
        # l'ancien comportement (peremption a PerimeMinutes). Mais on le dit.
        Write-Output "AVERTISSEMENT : le batteur n'a pas pu demarrer ($($_.Exception.Message)). Le verrou ne restera valable que $PerimeMinutes min sans rafraichissement."
        return $null
    }
}

function Stop-Batteur($pidBatteur) {
    if (-not (Test-BatteurVivant $pidBatteur)) { return }
    try { Stop-Process -Id $pidBatteur -Force -ErrorAction Stop } catch { }
}

# --- HORLOGE : UTC PARTOUT ---------------------------------------------------
# Corrige le 21/09/2026. Le meme script rendait DEUX heures differentes selon la
# facon dont il etait lance : en avant-plan l'horloge rendait l'heure NC (+1100),
# en arriere-plan elle rendait UTC, soit 11 h de moins, sans aucun avertissement.
# Constate ce jour-la : « verrou pris a 09:53 NC » alors qu'il etait 20h53 en NC.
#
# Le defaut n'etait pas cosmetique. Ces horodatages sont ECRITS dans un fichier
# d'etat que les autres routines relisent : des valeurs a 11 h d'ecart cohabitaient
# dans verrou-routines.json, et TOUS les calculs d'age devenaient faux. Un verrou
# pris en avant-plan paraissait « dans le futur » pour un lecteur UTC ; un verrou
# pris en arriere-plan paraissait vieux de 11 h, donc immediatement PERIME.
#
# Regle desormais : on STOCKE et on COMPARE en UTC, on n'AFFICHE qu'en NC.
# L'instant present ne se lit plus qu'avec Get-Maintenant, qui repose sur
# [datetime]::UtcNow : le meme instant quel que soit le fuseau du process.
# Meme famille que le piege TZ= du 03/09/2026.

# La Nouvelle-Caledonie est a UTC+11 toute l'annee (aucun changement d'heure) :
# le decalage est une constante, pas une base de fuseaux a interroger - et Git Bash
# comme certains contextes d'execution n'en embarquent aucune.
$script:DECALAGE_NC_HEURES = 11

function Get-Maintenant { [datetime]::UtcNow }

function Get-Horodatage { [datetime]::UtcNow.ToString('o') }

function Get-HeureNC {
    param([datetime]$Utc = [datetime]::UtcNow)
    return $Utc.AddHours($script:DECALAGE_NC_HEURES).ToString('HH:mm')
}

function ConvertTo-Date($s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    # AdjustToUniversal convertit vers UTC tout horodatage qui porte un decalage
    # (+11:00 comme +00:00), donc les valeurs ECRITES AVANT ce correctif restent
    # lues correctement ; AssumeUniversal n'est qu'un repli si le decalage manque.
    # Sans ces deux drapeaux, Parse rendrait une heure LOCALE, c'est-a-dire de
    # nouveau une valeur qui depend du contexte d'execution.
    try {
        return [datetime]::Parse(
            $s,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor
            [System.Globalization.DateTimeStyles]::AssumeUniversal)
    } catch { return $null }
}

function Get-Rang($nom) {
    if ($RANGS.ContainsKey($nom)) { return $RANGS[$nom] }
    return 99   # routine inconnue : passe en dernier, jamais bloquante pour les autres
}

# --- BATTRE (usage interne, jamais appele par une routine) -------------------
# Rafraichit 'battement' tant que la routine detient le verrou, puis s'arrete.
# Trois conditions d'arret, volontairement redondantes : la routine n'est plus
# detentrice, la duree maximale est atteinte, ou le process est tue par
# Stop-Batteur a la liberation.
if ($Battre) {
    $finBattement = (Get-Maintenant).AddHours($BattementMaxHeures)
    while ((Get-Maintenant) -lt $finBattement) {
        $suite = Update-Etat -Transformation {
            param($e)
            if ($e.detenteur -ne $Routine) { return @{ continuer = $false } }
            $e.battement = Get-Horodatage
            return @{ etat = $e; continuer = $true }
        }
        if (-not $suite.continuer) { break }
        Start-Sleep -Seconds $IntervalleBattementSecondes
    }
    exit 0
}

# --- ETAT -------------------------------------------------------------------
if ($Etat) {
    $e = Get-Etat
    Write-Output "Verrou   : $FICHIER"
    if ($e.detenteur) {
        $batt = ConvertTo-Date $e.battement
        $ageTxt = if ($batt) { "battement il y a $([int]((Get-Maintenant) - $batt).TotalMinutes) min" } else { "aucun battement enregistre" }
        $vivantTxt = if (Test-BatteurVivant $e.batteur_pid) { "batteur ACTIF (PID $($e.batteur_pid))" } else { "AUCUN batteur vivant" }
        Write-Output "DETENU par '$($e.detenteur)' depuis $($e.pris_a) ($ageTxt, $vivantTxt)"
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
# GARDE-FOU D'APPARTENANCE (15/09/2026, demande de Jean-Michel).
#
# Avant ce jour, -Liberer rendait le verrou MEME quand il appartenait a une
# autre routine : il se contentait d'un avertissement, puis liberait.
#
# Constate le 15/09/2026, sans degat mais la garantie etait levee :
#   11h52  perfeco-rapport-dimanche prend le verrou
#   13h07  son verrou est juge perime (PerimeMinutes = 45) alors qu'elle est
#          VIVANTE - 78 min est son regime normal (scraping 3 canaux,
#          archivage, analyse mensuelle) - et perfeco-verif-github-actions
#          (rang 7) le reprend
#   13h13  perfeco-rapport-dimanche se cloture ; trace-routine.ps1 libere le
#          verrou de perfeco-verif-github-actions, qui finit son execution
#          SANS PROTECTION. Une troisieme routine aurait pu demarrer dessus.
#
# Desormais : on ne rend que ce qu'on detient.
#
# MISE A JOUR DU 21/09/2026 : l'arbitrage laisse ouvert ici (« faire battre le
# verrou, ou relever PerimeMinutes ») est TRANCHE - c'est le battement qui a ete
# retenu, un seuil plus eleve n'aurait fait que repousser le probleme sans jamais
# distinguer une routine lente d'une routine morte. Ce garde-fou reste utile : il
# couvre les verrous pris par une version anterieure du script, et le cas ou le
# process de battement n'a pas pu demarrer.
if ($Liberer) {
    $r = Update-Etat -Transformation {
        param($e)
        $detenteur = $e.detenteur

        if ($detenteur -and $detenteur -ne $Routine -and -not $Force) {
            # La routine appelante est terminee : elle sort de la file d'attente,
            # sinon elle ferait patienter les suivantes indefiniment.
            $e.attente = @($e.attente | Where-Object { $_.routine -ne $Routine })
            return @{ etat = $e; refus = $true; detenteur = $detenteur; batteur = $null }
        }

        $batteur = $e.batteur_pid
        $e.detenteur = $null
        $e.pris_a = $null
        $e.battement = $null
        $e.batteur_pid = $null
        $e.derniere_liberation = Get-Horodatage
        $e.attente = @($e.attente | Where-Object { $_.routine -ne $Routine })
        return @{ etat = $e; refus = $false; detenteur = $detenteur; batteur = $batteur }
    }

    $detenteur = $r.detenteur

    if ($r.refus) {
        Write-Output "REFUS : le verrou est detenu par '$detenteur', pas par '$Routine'. RIEN n'a ete libere."
        Write-Output "  '$Routine' s'est donc fait reprendre son verrou pendant son execution"
        Write-Output "  (peremption a $PerimeMinutes min sans battement). Le verrou de '$detenteur'"
        Write-Output "  reste intact : c'est precisement le but de ce garde-fou."
        Write-Output "  Deblocage manuel si le verrou est reellement coince :"
        Write-Output "    & '$PSCommandPath' -Liberer -Routine '$Routine' -Force"
        exit 11
    }

    # Le batteur n'a plus lieu d'etre : le laisser vivre maintiendrait un
    # 'battement' frais sur un verrou libere, et la routine suivante croirait
    # a tort qu'une routine travaille encore.
    Stop-Batteur $r.batteur

    if ($detenteur -eq $Routine) {
        Write-Output "LIBERE : $Routine a $(Get-HeureNC) NC"
    } elseif (-not $detenteur) {
        Write-Output "RIEN A LIBERER : aucun detenteur enregistre. '$Routine' a tourne sans verrou"
        Write-Output "  (repris en cours de route, ou jamais pris). Cadence de $EspacementMinutes min"
        Write-Output "  appliquee a partir de maintenant."
    } else {
        Write-Output "LIBERE EN FORCE : verrou de '$detenteur' rendu par '$Routine' a $(Get-HeureNC) NC"
    }
    exit 0
}

# --- PRENDRE ----------------------------------------------------------------
if (-not $Prendre) { throw "Preciser -Prendre, -Liberer ou -Etat." }

$monRang = Get-Rang $Routine
$debutAttente = Get-Maintenant

# Inscription dans la file d'attente : c'est ce qui permet a une routine de rang
# inferieur, declenchee en meme temps au reveil, d'obtenir la priorite.
Update-Etat -Transformation {
    param($e)
    $e.attente = @($e.attente | Where-Object { $_.routine -ne $Routine })
    $e.attente += [pscustomobject]@{ routine = $Routine; rang = $monRang; depuis = (Get-Horodatage) }
    return @{ etat = $e }
} | Out-Null

# Laisse 20 s aux routines declenchees dans la meme rafale pour s'inscrire aussi,
# sinon la premiere arrivee passe toujours, quel que soit son rang.
Start-Sleep -Seconds 20

$finBloquante = (Get-Maintenant).AddMinutes($AttenteBloquanteMax)

$script:AutoriserForce = $false

while ($true) {
    # Le droit de forcer se calcule DEHORS (il depend de l'anciennete de cette
    # invocation), mais il ne s'applique QUE dans la transaction, et jamais
    # par-dessus un detenteur vivant - voir plus bas.
    if (((Get-Maintenant) - $debutAttente).TotalMinutes -ge $AbandonApresMinutes) {
        $script:AutoriserForce = $true
    }

    # TOUTE la decision tient dans une seule transaction : evaluer l'etat puis
    # ecrire « le verrou est a moi » doit etre indivisible. Quand c'etait en deux
    # temps, deux routines pouvaient constater « libre » au meme instant et se
    # l'attribuer toutes les deux.
    $d = Update-Etat -Transformation {
        param($e)
        $maintenant = Get-Maintenant
        $motif = $null
        $vivant = $false
        $messages = @()

        # 1. Le verrou est-il detenu par une routine encore vivante ?
        if ($e.detenteur -and $e.detenteur -ne $Routine) {
            $batt = ConvertTo-Date $e.battement
            $age = if ($batt) { [int]($maintenant - $batt).TotalMinutes } else { $null }

            if (Test-BatteurVivant $e.batteur_pid) {
                # Preuve directe qu'un process travaille encore : on ne reprend
                # jamais un verrou dans ce cas, meme tres ancien.
                $ageTxt = if ($null -ne $age) { "depuis $age min" } else { "age inconnu" }
                $motif = "'$($e.detenteur)' tourne encore ($ageTxt, batteur PID $($e.batteur_pid) actif)"
                $vivant = $true
            } elseif ($batt -and ($maintenant - $batt).TotalMinutes -lt $PerimeMinutes) {
                # Pas de batteur vivant : soit il demarre a l'instant meme (le PID
                # n'est enregistre qu'une fraction de seconde apres la prise), soit
                # le verrou vient d'une version anterieure du script, soit le
                # batteur n'a pas pu demarrer. Dans les trois cas on retombe sur
                # l'ancienne regle de peremption, qui reste sure ici.
                $precision = if (($maintenant - $batt).TotalSeconds -lt 60) { "batteur en cours de demarrage" } else { "sans batteur" }
                $motif = "'$($e.detenteur)' tourne encore (depuis $age min, $precision)"
                $vivant = $true
            } else {
                $messages += "Verrou perime de '$($e.detenteur)' (aucun batteur vivant et aucun battement depuis plus de $PerimeMinutes min) : repris."
                $e.detenteur = $null
                $e.pris_a = $null
                $e.battement = $null
                $e.batteur_pid = $null
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

        # Garde-fou : mieux vaut tourner en retard que jamais - MAIS jamais
        # par-dessus une routine vivante. Forcer dans ce cas produirait exactement
        # ce que ce verrou existe pour empecher : deux routines en parallele.
        # Un blocage de cadence ou de priorite, lui, peut etre force sans risque.
        $forcer = ($motif -and $script:AutoriserForce -and -not $vivant)

        if (-not $motif -or $forcer) {
            $e.detenteur = $Routine
            $e.pris_a = Get-Horodatage
            $e.battement = Get-Horodatage
            $e.batteur_pid = $null
            $e.attente = @($e.attente | Where-Object { $_.routine -ne $Routine })
            $issue = if ($forcer) { 'force' } else { 'pris' }
            return @{ etat = $e; issue = $issue; motif = $motif; messages = $messages }
        }

        return @{ etat = $e; issue = 'attendre'; motif = $motif; vivant = $vivant; messages = $messages }
    }

    foreach ($m in $d.messages) { Write-Output $m }

    if ($d.issue -eq 'pris' -or $d.issue -eq 'force') {
        # Le batteur demarre APRES la prise : il n'a de sens que si le verrou est
        # effectivement a nous. La fenetre sans PID enregistre est sans danger,
        # 'battement' venant d'etre ecrit a l'instant.
        $pidBatteur = Start-Batteur $Routine
        if ($pidBatteur) {
            Update-Etat -Transformation {
                param($e)
                if ($e.detenteur -ne $Routine) { return @{} }
                $e.batteur_pid = $pidBatteur
                $e.battement = Get-Horodatage
                return @{ etat = $e }
            } | Out-Null
        }

        $attendu = [int]((Get-Maintenant) - $debutAttente).TotalMinutes
        if ($d.issue -eq 'force') {
            Write-Output "FORCE : $AbandonApresMinutes min d'attente depassees ($($d.motif)). Verrou pris quand meme."
            Write-Output "SIGNALER CE PASSAGE EN FORCE DANS LE BROUILLON GMAIL ET DANS -Alerte."
        } else {
            Write-Output "LIBRE : verrou pris par '$Routine' (rang $monRang) a $(Get-HeureNC) NC apres $attendu min d'attente."
        }
        Write-Output "Poursuivre la routine normalement. Le verrou sera libere par trace-routine.ps1."
        exit 0
    }

    if ((Get-Maintenant) -ge $finBloquante) {
        Write-Output "ATTENDRE : $($d.motif)"
        Write-Output "Rappeler ce script a l'identique dans 5 minutes. Ne RIEN faire d'autre entre-temps."
        if ($d.vivant -and $script:AutoriserForce) {
            # Le seul cas ou l'attente peut durer : une routine vivante travaille
            # depuis longtemps. C'est voulu, mais il faut pouvoir en sortir.
            Write-Output "  Le detenteur est VIVANT : aucun passage en force ne sera tente, sinon deux routines"
            Write-Output "  tourneraient en meme temps. Si ce verrou est reellement coince, le rendre a la main :"
            Write-Output "    & '$PSCommandPath' -Liberer -Routine '<detenteur>' -Force"
        }
        exit 10
    }

    Start-Sleep -Seconds 45
}
