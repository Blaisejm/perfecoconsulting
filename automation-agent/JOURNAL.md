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

**`effet` et `preuve` sont le cœur.** Une ligne qui dit « routine exécutée » sans dire
quoi ni le prouver reproduit exactement le défaut du `lastRunAt`.

`rien-a-faire` est un résultat légitime et attendu — la relance quotidienne l'écrira la
plupart des jours. Ce qui doit alerter, c'est le **silence**, pas l'inaction assumée.

## Comment écrire sa ligne

Dernière étape de la routine, après tout le reste :

```bash
cd C:\Projets\perfecoconsulting
echo '{"routine":"...","fin_nc":"...","resultat":"...","effet":"...","preuve":"...","alerte":null}' >> automation-agent/journal-executions.jsonl
git add automation-agent/journal-executions.jsonl
git commit -m "journal: <routine> - <resultat>"
git pull --no-edit origin main
git push origin main
```

Format en ajout seul, une ligne par enregistrement : deux routines qui écrivent le même
jour ne produisent pas de conflit de fusion.

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
