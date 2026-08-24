# Journal d'exécution des routines PerfEco

**Fichier : `automation-agent/journal-executions.jsonl`** — une ligne JSON par exécution,
en ajout seul, versionnée dans git.

## Pourquoi il existe

Posé par Jean-Michel le 21/08/2026 : *« il est important de déterminer quel traitement
est intervenu en dernier dans cette routine et avec quel résultat, soit date et heure. »*

Jusqu'ici, la seule trace d'une routine Cowork était son `lastRunAt`. **Ce champ prouve
un déclenchement, jamais un résultat.** La démonstration a eu lieu le jour même :

| | |
|---|---|
| `perfeco-veille-eco-21082026` | `lastRunAt` = 20/08 09:00:40, tâche auto-désactivée comme accomplie |
| Ce qu'elle a réellement écrit | **rien** — git ne montre aucun commit de sa part |
| Qui a fait le travail | la relance quotidienne, la veille à 21h12 (commit `073768a`) |

Onze occurrences de ce motif sont documentées depuis le 12/07/2026. Aucun tableau de bord
ne pouvait les distinguer d'un succès.

## Le principe

**Une routine écrit sa ligne EN FIN d'exécution, jamais au début.**

C'est ce qui rend le journal fiable : une routine qui meurt au premier appel d'outil —
le mode de défaillance dominant, jeton OAuth expiré — n'écrit rien. **L'absence de ligne
est le signal**, et elle est visible depuis GitHub Actions, qui ne dépend pas du jeton
Cowork. Une routine morte ne peut pas mentir sur son propre compte.

## Format d'une ligne

```json
{"routine":"vendredi-veilleeco-creation","fin_nc":"2026-08-19T08:41:00+11:00","resultat":"succes","effet":"contenu veille eco 28/08 produit et mis en staging","preuve":"commit b8c33ce","alerte":null}
```

| Champ | Obligatoire | Contenu |
|---|---|---|
| `routine` | ✅ | identifiant exact de la tâche |
| `fin_nc` | ✅ | horodatage ISO **de fin**, fuseau `+11:00` |
| `resultat` | ✅ | `succes` · `echec` · `rien-a-faire` |
| `effet` | ✅ | ce qui a **changé**, en clair. Jamais « routine exécutée » |
| `preuve` | ✅ | commit, chemin de fichier, URL, identifiant de brouillon… ou `"aucune"` |
| `alerte` | ✅ | ce qui reste bloqué, ou `null` |
| `fichiers` | ✅ | *(depuis le 21/08/2026)* chemins réellement modifiés, renseignés automatiquement |
| `commits` | ✅ | *(depuis le 21/08/2026)* `suivi=<hash>` et/ou `projet=<hash>` |

**`effet` et `preuve` sont le cœur.** Une ligne qui dit « routine exécutée » sans dire
quoi ni le prouver reproduit exactement le défaut du `lastRunAt`.

`rien-a-faire` est un résultat légitime et attendu — la relance quotidienne l'écrira la
plupart des jours. Ce qui doit alerter, c'est le **silence**, pas l'inaction assumée.

## Comment écrire sa ligne

**Une seule commande, en toute dernière étape.** Ne plus écrire la ligne à la main.

```powershell
& 'C:\Projets\perfecoconsulting\automation-agent\trace-routine.ps1' `
    -Routine "<nom exact de la tache>" `
    -Resultat "succes" `
    -Effet   "<ce qui a CHANGE>" `
    -Preuve  "<commit, fichier, URL, id de brouillon, ou aucune>" `
    -Alerte  "<ce qui reste bloque, ou omettre>"
```

Le script fait trois choses que la méthode manuelle ne faisait pas :

1. Il commite les modifications **des deux dépôts** — `C:\Projets\perfecoconsulting`
   *et* `C:\Users\jmbla\OneDrive\Documents\claude IA` (la zone de suivi, versionnée
   depuis le 21/08/2026 seulement).
2. Il signe ces commits **du nom de la routine**, pas de « Jean-Michel Blaise ».
3. Il renseigne `fichiers` et `commits` tout seul, à partir de ce que git constate —
   donc sans risque d'oubli ni de déclaration inexacte.

Format en ajout seul, une ligne par enregistrement : deux routines qui écrivent le même
jour ne produisent pas de conflit de fusion.

## Retrouver qui a touché quoi

C'est la raison d'être du dispositif — question posée par Jean-Michel le 21/08/2026 :
*« Tu dois à tout moment savoir précisément quelle routine a travaillé sur un fichier et
à quel moment. »*

```powershell
# Historique d'un fichier : chaque passage, sa routine, sa date
& 'C:\Projets\perfecoconsulting\automation-agent\qui-a-touche.ps1' SUIVI-AUTOMATISATION.md

# Tout ce qu'une routine a modifié
& 'C:\Projets\perfecoconsulting\automation-agent\qui-a-touche.ps1' -Routine mardi-carrousel-creation

# Vue d'ensemble : dernier passage de chaque routine, silences signalés en rouge
& 'C:\Projets\perfecoconsulting\automation-agent\qui-a-touche.ps1'
```

Et directement en git, puisque l'auteur du commit est la routine :

```bash
git log --format="%an  %ad  %s" --date=short -- <fichier>
git log --author=perfeco-rappel-quotidien
```

### Deux limites à connaître

- **Le dépôt de suivi n'a pas de remote.** Il vit sur le disque, répliqué par OneDrive.
  L'historique est donc local : une perte de la machine emporterait les versions, pas les
  fichiers eux-mêmes (OneDrive les conserve). Un dépôt GitHub privé lèverait ce point —
  décision à prendre par Jean-Michel, rien n'est poussé sans son accord.
- **Six scripts ne sont pas versionnés** car ils contiennent un secret en dur (token
  LinkedIn, webhooks Make.com) — voir le bloc dédié dans `.gitignore` de la zone de suivi.
  Leurs modifications restent tracées par le champ `fichiers` du journal, mais sans diff.
  À réintégrer une fois les secrets sortis du code.

## Les définitions de routines sont versionnées aussi (24/08/2026)

Jusqu'au 24/08/2026, tout ce dispositif traçait les fichiers de travail — pas les
**consignes** qui pilotent les routines. Or celles-ci vivent dans
`C:\Users\jmbla\.claude\scheduled-tasks\<nom>\SKILL.md`, qui n'est un dépôt d'aucune sorte :
une consigne pouvait dériver du réel sans date ni auteur, et c'est le mécanisme commun à
trois dérives déjà payées.

| Quand | La consigne disait | Le réel était |
|---|---|---|
| 21/08 | « le samedi est suspendu depuis le 18/08 » | le cron avait été réactivé le 18/08 même — le workflow tournait sans surveillance |
| 18/08 | surveiller `publish-lundi-facebook.yml` | supprimé du dépôt le 12/08 ; l'API renvoyait son vieux run en `success`, faux « tout va bien » |
| 24/08 | 7 workflows à surveiller | 9 actifs, dont le filet indépendant lui-même |

`sync-routines.ps1` miroite donc les définitions dans `<suivi>/routines/<nom>.SKILL.md`,
avec un `INVENTAIRE.md` généré. **Il est appelé par `trace-routine.ps1` à chaque clôture**,
avant les commits : toute routine qui clôture emporte le miroir avec elle. Confier cette
synchro à une routine dédiée l'aurait exposée au mode de défaillance dominant — la routine
qui meurt à son premier appel d'outil et n'écrit rien.

```powershell
# Ce qu'une consigne disait avant, et quand elle a changé
git -C "C:\Users\jmbla\OneDrive\Documents\claude IA" log --follow -p -- routines/perfeco-rappel-quotidien.SKILL.md
```

**Trois choses à savoir.** Le dossier `routines/` est un **miroir, pas la source** : y
éditer un fichier ne change rien au comportement d'une routine et sera écrasé à la synchro
suivante. L'auteur du commit est la routine qui passait là, pas celle qui a modifié la
consigne — les définitions sont éditées par des sessions Claude ; ce qu'on gagne est
l'historique du texte et sa date, qui manquaient totalement. Enfin le script **refuse
d'écrire dans un dépôt ayant un remote** (`-AutoriserDepotDistant` pour lever le garde-fou) :
`perfecoconsulting` est public, et ces définitions portent arbitrages, prospects et
tactique commerciale — aucun identifiant, c'est vérifié, mais rien qui doive être publié.

## Qui doit en écrire

**Toutes les routines Cowork**, y compris les tâches one-time — ce sont elles qui ont
échoué le plus souvent.

**Pas les workflows GitHub Actions** : leur historique de runs est déjà une preuve
authoritative, horodatée et indépendante de Cowork. Les inscrire ici ajouterait du bruit
et un second endroit où chercher la vérité.

## Comment il est contrôlé

`scripts/controle-pipeline.mjs`, appelé chaque jour par
`.github/workflows/check-preparation-contenu.yml`, compare la dernière ligne de chaque
routine à sa `tolerance_jours` déclarée dans `calendrier.json`. Au-delà, il alerte.

Comme ce contrôle tourne dans GitHub Actions, il reste debout quand Cowork tombe — ce qui
est précisément le cas qu'il doit détecter.
