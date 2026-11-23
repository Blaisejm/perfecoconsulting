# Référentiel « Campagne V3 — Performance » (jeudi)

Plan validé par Jean-Michel le 23/11/2026 (« OK les deux »). 10 posts courts + visuel au gabarit
V2 + article de fond perfsystemique.fr, du jeudi 04/02/2027 au jeudi 08/04/2027. La V2 s'arrête
le 17/12/2026 au 8/10 ; ses 9/10 et 10/10 passent aux jeudis 21/01 et 28/01/2027 (référentiel
`REFERENTIEL-V2-PERFORMANCE.md` §4).

**Le registre `automation-agent/publications.json` reste maître des dates.** La routine
`creation-jeudi-cloud` lit ce fichier quand le `libelle` de l'échéance contient « Campagne V3 ».

## Ce qui ne change pas par rapport à la V2

- Même gabarit : `production/gabarits/gabarit-v2-performance.html` (bandeau #163D78, accent #FBAA16).
- Même structure : situation → conséquence → méthode → résultat → invitation.
- Même registre conseil (reconnaître ce qui a été tenté, une seule recommandation, clôture positive),
  mêmes canaux (LinkedIn Company + profil perso le jeudi, Facebook le samedi en reprise), même
  article de fond sur perfsystemique.fr.
- Fichiers du visuel : préfixe `v3-<NN>-<slug>` au lieu de `v2-<NN>-<slug>`.
- **Pas d'argent** (cash, marges, coûts) : ce terrain appartient à la série 3 du mardi
  (`SERIE-3-LE-CASH-DABORD.md`), qui tourne les mêmes semaines.
- Appel à l'action : une question liée au sujet ; le Diagnostic stratégique 60 minutes seulement
  au 10/10.

## Les 10 publications (deux par territoire)

| # | Jeudi | Sujet | Territoire |
|---|---|---|---|
| 1 | 04/02/2027 | Une rentrée qui commence par trois priorités, pas dix | Du cap à la mise en œuvre |
| 2 | 11/02/2027 | Le passage de relais entre deux services — qui attend quoi de qui, et pour quand | Mieux travailler ensemble |
| 3 | 18/02/2027 | Une seule version des chiffres — quand chaque service a son propre tableau Excel | Piloter avec une information fiable |
| 4 | 25/02/2027 | Les validations en cascade — qui signe vraiment, et à quel montant | Simplifier le fonctionnement |
| 5 | 04/03/2027 | Dire non à un projet pour réussir les autres | Du cap à la mise en œuvre |
| 6 | 11/03/2027 | Les 90 premiers jours d'un nouveau responsable (compétences et relève) | Mieux travailler ensemble |
| 7 | 18/03/2027 | L'IA au bureau : commencer par une tâche, pas par un outil (gouvernance, aucune technique) | Simplifier le fonctionnement |
| 8 | 25/03/2027 | Les risques qu'on ne regarde qu'après coup | Piloter avec une information fiable |
| 9 | 01/04/2027 | Mesurer avant de changer : le point zéro | Prouver les résultats |
| 10 | 08/04/2027 | Ce qui reste six mois après un projet d'amélioration + Diagnostic stratégique 60 minutes | Prouver les résultats |

## Écarts d'angle à tenir

- **V3-1** face à la série 2, épisode 4 (cascade d'objectifs) : V3-1 parle du **choix** des
  priorités à la rentrée, l'épisode 4 parlait de leur descente dans l'organisation.
- **V3-3** face à la V2-3 (« Un reporting qui aide à décider ») : V3-3 parle de la **source unique**
  des données, pas de la forme du rapport.
- **V3-9 et V3-10** face aux V2-9 et V2-10 : l'angle porte sur la **mesure** (le point de départ,
  puis ce qui reste dans la durée), pas sur les gains rapides.

## Après le 08/04/2027

Les jeudis du 15/04 au 27/05/2027 restent libres (la « Banque visuels V2 » n'est pas retenue pour
l'instant, Jean-Michel, 23/11/2026). Le compteur de fin de campagne de `jeudi-creation.md` lèvera
l'alerte quand il restera deux épisodes.
