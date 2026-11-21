---
name: relecture-fr-perfeco
description: Contrôle qualité du français de toute publication PerfEco (posts LinkedIn/Facebook mardi, jeudi, vendredi, titres de visuels) AVANT sa mise en file d'attente — fautes de langue via LanguageTool, puis relecture indépendante « lecteur COMEX » sur la clarté, l'adaptation et l'impact, puis réécriture ciblée. À utiliser par les routines mardi-carrousel-creation, mercredi-creation et perfeco-rappel-quotidien, et chaque fois qu'un texte destiné à être publié est rédigé ou modifié à la main.
---

# Relecture FR PerfEco

**Demande de Jean-Michel du 07/10/2026 :** *« les textes ne sont pas toujours bien compréhensibles
ou adaptés ou percutants en FR »*. Le défaut de fond : **le même modèle écrivait et validait**.
Cette skill sépare les deux rôles.

**Quand :** après la rédaction du texte final, **avant** d'écrire le fichier de file d'attente
(`automation-queue/*.json` ou son staging). Un texte déjà en file se relit aussi : on corrige le
fichier, on commite, on pousse.

**Ce qui ne change JAMAIS pendant la relecture :** les chiffres, les sources et leurs dates, le
sujet et l'angle arrêtés, la recommandation unique, les coordonnées, les hashtags. On améliore
la langue et l'impact, on ne change pas le fond. Si le relecteur conteste le fond, on le
**signale** à Jean-Michel dans le brouillon Gmail, on ne réécrit pas.

---

## Étape 1 — Couche mécanique (LanguageTool + signaux de lisibilité)

```bash
cd /c/Projets/perfecoconsulting
node scripts/relecture-fr.mjs automation-queue/<fichier>.json      # ou --texte "…"
```

| Code de sortie | Sens | Ce que tu fais |
|---|---|---|
| `0` | aucune faute de langue | passe à l'étape 2 |
| `1` | au moins une faute (`✖`) | **corrige chaque `✖`**, ou écarte-le en écrivant pourquoi c'est un faux positif (ex. « estiment manquer » est correct : infinitif après un verbe d'opinion). Relance jusqu'à ce qu'il ne reste que des faux positifs justifiés. |
| `2` | LanguageTool injoignable | le contrôle **n'a pas tourné** : ce n'est ni un succès ni un échec. Fais l'étape 2 quand même, et écris « relecture mécanique NON EXÉCUTÉE » dans le brouillon Gmail. |

Les `⚠` (phrases longues, jargon, négations multiples, antithèses, mots creux, répétitions,
calques) ne bloquent pas : ce sont des **pistes** que tu transmets au relecteur de l'étape 2.

---

## Étape 2 — Relecteur indépendant (le cœur de la skill)

Lance un **sous-agent** (outil `Agent`, type `general-purpose`) qui ne voit **que le texte final**
et les exemples de calibrage, jamais ton brief, tes recherches ni tes intentions. C'est ce qui le
rend indépendant : il lit comme le lecteur, pas comme l'auteur.

Prompt à lui passer, à l'identique, en remplaçant les deux blocs :

```
Tu es un dirigeant d'entreprise en Nouvelle-Calédonie (PDG, DAF ou COO d'une structure de
30 à 500 personnes). Tu fais défiler LinkedIn sur ton téléphone entre deux réunions. Tu ne
connais pas l'auteur et tu n'as aucun contexte sur ce texte.

Lis d'abord les exemples de calibrage : ils montrent ce que l'auteur du compte juge mauvais,
et pourquoi. Applique le même niveau d'exigence.
<<< contenu de base-connaissance/relecture-fr-exemples.md >>>

Puis lis ce texte, une seule fois, comme tu le ferais vraiment :
<<< texte du post, tel qu'il partira >>>

Signaux relevés par l'outil automatique (à vérifier, pas à croire) :
<<< les ⚠ de l'étape 1 >>>

Réponds en français, dans ce format exact :

NOTES (1 à 5, 5 = excellent) :
- Clarté : compris en une lecture, sans revenir en arrière ?
- Concret : des choses que je vois (dossiers, heures, réunions) plutôt que des notions ?
- Naturel : est-ce qu'un Calédonien le dirait à voix haute ? aucune tournure traduite ou ampoulée ?
- Accroche : les deux premières lignes me donnent-elles envie de cliquer sur « voir plus » ?
- Utilité : est-ce que je sais quoi faire lundi matin ?

PASSAGES FAIBLES (au plus 6, du plus grave au moins grave) :
- « citation exacte » → problème en une ligne → réécriture proposée

VERDICT : PUBLIABLE / À RETOUCHER / À REPRENDRE

Règles pour tes réécritures : ne change aucun chiffre, aucune source, aucune date, ni le
conseil donné. Une phrase = une idée. Préfère l'affirmation à la négation, le verbe au nom,
le mot courant au mot savant. Pas d'antithèse du type « X au lieu de Y ». Garde les emoji
en tête de paragraphe et le tutoiement/vouvoiement d'origine.
```

**Si l'outil `Agent` n'est pas disponible** dans la session : fais la relecture toi-même, mais
dans un passage séparé, en relisant le texte comme s'il venait d'un tiers, avec la même grille, et
**signale dans le brouillon Gmail que la relecture n'était pas indépendante**.

---

## Étape 3 — Arbitrer et réécrire

1. **Seuil :** toute note ≤ 3, ou un verdict autre que PUBLIABLE, impose une retouche.
2. **Applique les réécritures** qui améliorent réellement le texte. Tu peux en refuser une si elle
   change le fond, casse la structure du registre conseil (reconnaître → pourquoi ça ne suffit pas
   → une recommandation → clôture positive) ou affaiblit l'accroche — **note pourquoi**.
3. **Relance l'étape 1** sur le texte retouché (une retouche peut introduire une faute).
4. **Une seule boucle de relecture indépendante suffit** en temps normal. Si le verdict était
   « À REPRENDRE », relance l'étape 2 une fois sur la version retouchée.
5. Revérifie les règles PerfEco que la réécriture pourrait avoir cassées : emoji en tête de chaque
   idée, coordonnées sur leur ligne, une seule négation par phrase, source citée.

**Titres de visuels :** passe aussi le titre et le sous-titre de la slide à l'étape 1 (`--texte`)
et à la question « compris en 2 secondes ? ». Une correction de titre impose un ré-export du PNG et
un redéploiement — à faire **avant** la mise en file.

---

## Étape 4 — Rendre compte

Dans le brouillon Gmail de la routine, pour chaque texte relu, une ligne du type :

> 🔤 **Relecture FR** — LanguageTool : 0 faute (2 faux positifs écartés : …) · Relecteur :
> clarté 3→5, concret 4→4, naturel 2→4, accroche 3→4, utilité 5→5 · 4 retouches appliquées
> (ex. « il gagne un calendrier » → « il sait enfin pour quand il travaille »), 1 refusée (changeait
> le conseil).

C'est ce qui permet à Jean-Michel de juger si l'outil s'améliore — et de le corriger.

---

## Calibrage — la partie qui fait progresser l'outil

`C:\Users\jmbla\OneDrive\Documents\claude IA\Perfeco-Social-Media\base-connaissance\relecture-fr-exemples.md`

Chaque fois que Jean-Michel critique un texte publié ou en file (« pas clair », « pas percutant »,
une reformulation de sa main), **ajoute l'exemple à ce fichier** : la phrase d'origine, ce qui
cloche selon lui, sa version ou la version validée. Un relecteur générique ne connaît pas son
goût ; ces exemples, si. Les siens priment toujours sur ceux écrits par Claude.

## Fichiers

| Rôle | Chemin |
|---|---|
| Script mécanique | `C:\Projets\perfecoconsulting\scripts\relecture-fr.mjs` |
| Exemples de calibrage | `Perfeco-Social-Media\base-connaissance\relecture-fr-exemples.md` |
| Règles typographiques des visuels | `controle-editorial.mjs` (inchangé, complémentaire) |
