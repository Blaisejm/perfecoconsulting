# Règles de livraison des routines PerfEco

Deux règles posées par Jean-Michel le **12/09/2026**. Elles s'appliquent à **toutes** les
routines, sans exception, et à **toutes les diffusions médias ou publications**.

Ce fichier est la référence. Chaque fiche `SKILL.md` en porte une version courte et
auto-suffisante : une routine doit pouvoir appliquer la règle sans avoir lu ce fichier.
Ce fichier existe pour trancher les cas limites et pour porter le *pourquoi*.

---

## Règle 1 — toute routine se nomme dans ce qu'elle produit

> « Toutes les routines qui produisent des brouillons de mails ou de rapport, etc.
> indiquent leur dénomination dans le mail envoyé, surtout si elles me demandent une ou
> des validations. »

**Ce qui doit apparaître, dans tout brouillon Gmail, tout rapport et tout fichier livré :**

1. **Dans l'objet**, le nom de la routine entre crochets :
   `[PerfEco · <nom-de-la-routine>] <objet lisible>`
   Le mot `PerfEco` est conservé en tête — les recherches et filtres existants continuent
   de fonctionner. Le nom de la routine est celui du dossier
   `C:\Users\jmbla\.claude\scheduled-tasks\<nom>\`, à l'identique, sans reformulation.

2. **Première ligne du corps**, avant tout contenu :
   `Routine : <nom-de-la-routine> — exécutée le JJ/MM/AAAA à HHhMM (NC)`

3. **Bloc de pied**, en fin de message :
   ```
   ── Produit par la routine <nom-de-la-routine>
      Consigne : C:\Users\jmbla\.claude\scheduled-tasks\<nom>\SKILL.md
      Historique de la consigne : git log -p -- routines/<nom>.SKILL.md
                                  (dépôt « OneDrive\Documents\claude IA »)
   ```

**Pourquoi l'objet ET le corps.** Sur téléphone, l'objet est souvent tronqué : le nom peut
disparaître là où il sert le plus. Le corps, lui, est toujours lu en entier. Et à l'inverse,
dans une boîte qui reçoit six brouillons dans la semaine, seul l'objet permet de trier sans
ouvrir. Les deux sont nécessaires — aucun ne remplace l'autre.

**Effet de bord voulu sur l'anti-doublon.** Les routines interrogeaient
`list_drafts` avec `query: "subject:\"[PerfEco]\" newer_than:1d"`. Ce filtre est commun à
toutes : le brouillon d'une routine pouvait faire taire une autre le même jour. Le nom
étant maintenant dans l'objet, la requête devient
`query: "subject:\"<nom-de-la-routine>\" newer_than:1d"` — chaque routine ne se compare
plus qu'à elle-même. C'est un défaut latent corrigé au passage, pas un simple ajustement.

---

## Règle 2 — 48 h pour valider, ensuite le système tranche seul

> « Je dispose de 48 h pour valider un sujet ou une publication, au-delà le système est
> supposé prendre la meilleure solution, tout seul. Cette règle est valide pour toutes les
> diffusions médias ou publications. »

### Une demande de validation recevable comporte cinq éléments

| # | Élément | Pourquoi |
|---|---|---|
| 1 | Une **question fermée**, avec des options numérotées | « Quel angle voulez-vous ? » n'est pas arbitrable en 48 h ; « 1, 2 ou 3 ? » l'est |
| 2 | L'**option par défaut**, désignée explicitement | C'est elle qui partira sans réponse. Elle doit être la meilleure disponible, jamais « on ne publie pas » |
| 3 | La **date et l'heure limites**, en clair, heure NC | Un délai qu'on ne peut pas lire n'est pas un délai |
| 4 | Ce que la réponse **change concrètement** | Deux options équivalentes ne méritent pas une question |
| 5 | L'**enregistrement au registre** (voir plus bas) | Un brouillon supprimé ne doit pas emporter la question avec lui |

**Une demande sans option par défaut n'est pas une demande de validation : c'est un blocage
déguisé.** Le script `validations.ps1 -Ouvrir` refuse d'enregistrer une question sans
`-Defaut`. Ce refus est le cœur de la règle : la solution de repli doit être trouvée au
moment où la question se pose, quand il reste du temps pour bien choisir — pas 48 h plus
tard sous la pression de l'échéance.

### Le registre — `automation-agent/validations.json`

Le délai est inapplicable sans horodatage : personne ne peut savoir que 48 h sont écoulées
si personne n'a noté l'heure de la question. Toute demande passe donc par :

```powershell
& 'C:\Projets\perfecoconsulting\automation-agent\validations.ps1' -Ouvrir `
    -Routine "<nom-de-la-routine>" `
    -Objet    "<libellé court, sert de clé anti-doublon>" `
    -Question "<la question, avec ses options>" `
    -Options  "option 1","option 2" `
    -Defaut   "<ce qui partira sans réponse, et pourquoi c'est le meilleur choix>" `
    -Impact   "<ce que la réponse change>" `
    -Publication "<id dans publications.json, si la question porte sur une diffusion>" `
    -Avant    "<AAAA-MM-JJTHH:mm:ss+11:00 — heure de diffusion moins 2 h>"
```

`-Ouvrir` est **idempotent** sur (routine + objet). Une routine rattrapée trois jours de
suite ne crée pas trois questions et **ne remet pas le compteur à zéro**. Sans cette
propriété, une routine qui se rattrape chaque jour repousserait éternellement sa propre
échéance de 48 h, et la règle ne se déclencherait jamais.

### Le délai court à partir de la question POSÉE, pas de la question détectée

Trouvé au premier essai du script, le 12/09/2026 : l'arbitrage « Ascension du jeudi 6 mai
2027 » avait été ouvert par `etendre-cahier.ps1` le 21/08/2026 et apparaissait « échu
depuis 486 h ». Or Jean-Michel ne l'a jamais reçu — `perfeco-rappel-quotidien` ne relaie
délibérément pas une question à plus de 21 jours d'échéance, pour ne pas noyer les vraies
alertes. Trancher d'office une question jamais posée, ce n'est pas appliquer la règle des
48 h, c'est la retourner contre son auteur.

Donc : le compteur démarre au **premier brouillon Gmail qui porte effectivement la
question**. La routine l'atteste au moment de créer le brouillon :

```powershell
& '...\validations.ps1' -Relayer -Id <id>
```

Tant que rien n'a été relayé, la question est « à poser » — jamais « échue ».

### Écrêtage : 48 h, mais jamais après la diffusion

Le délai retenu est **le plus court des deux** : 48 h, ou l'heure de diffusion moins 2 h.
Une question posée 30 h avant la publication du vendredi ne peut pas attendre 48 h — elle
serait tranchée après coup. C'est le rôle de `-Avant`, qui écrête automatiquement et le
signale (`ecrete: true`). Quand le délai est écrêté, **le brouillon doit le dire** : le
délai annoncé à Jean-Michel doit être le vrai.

### Ce qui se passe à l'expiration

L'application des défauts se fait au premier passage utile, dans cet ordre :

1. **Chaque routine de production**, en tête d'exécution, avant de produire quoi que ce
   soit : elle applique les défauts échus **qui concernent sa propre publication**. C'est
   le passage le plus proche de la diffusion, donc le plus fiable.
2. **`perfeco-rappel-quotidien`** (08h00 NC, tous les jours) : le filet. Il applique tous
   les défauts échus restants, quelle que soit la routine d'origine.

Dans les deux cas, la séquence est **toujours** : appliquer le défaut **au contenu**
d'abord, `validations.ps1 -AppliquerDefauts` ensuite. Le registre acte une décision
exécutée ; il ne la remplace pas. Marquer « tranché par défaut » sans avoir produit le
contenu correspondant, c'est fabriquer la panne que ce registre est censé prévenir.

### Après l'expiration, ce n'est plus une question

Le brouillon suivant ne réaffiche pas la question. Il annonce **une décision prise**, en
tête, dans cette forme :

> ⚖️ **Décidé sans vous, délai de 48 h écoulé** — « Angle trésorerie T3 » retenu pour le
> carrousel du 29/09 (question posée le 25/09 à 08h05, sans réponse au 27/09 à 08h05).
> Le contenu est produit et en file d'attente. Pour revenir dessus : il reste jusqu'au
> 28/09 11h00 avant diffusion.

Trois choses y sont obligatoires : **ce qui a été décidé**, **que le délai en est la
cause**, et **jusqu'à quand c'est encore réversible**. Une décision prise sans réponse
reste une décision à laquelle Jean-Michel doit pouvoir s'opposer tant que rien n'est parti.

### Ce que la règle ne couvre pas

Le délai de 48 h vaut pour **les sujets, les angles, les publications et les diffusions
médias** — ce qui se produit et se diffuse. Il ne s'applique pas à :

- **Ce que Jean-Michel seul peut faire.** Un clic « Autoriser » sur LinkedIn, un
  renouvellement de token, une saisie de mot de passe : aucun défaut n'existe, le système
  ne peut pas se substituer à lui. Ces demandes-là continuent de relancer jusqu'à
  résolution — elles ne s'enregistrent pas comme validations.
- **Une donnée absente ou invérifiable.** La règle du vendredi reste plus forte :
  *ne jamais inventer un chiffre ou une source pour tenir un délai.* S'il manque une donnée
  vérifiable, le défaut est de changer d'angle pour un angle sourcé, jamais de publier un
  chiffre non vérifié. Un contenu faux est pire qu'un contenu en retard.
- **Les décisions engageantes hors publication** : dépense, engagement contractuel,
  réponse à un appel d'offres. Elles se relancent, elles ne se tranchent pas d'office.

---

## Consulter

```powershell
& 'C:\Projets\perfecoconsulting\automation-agent\validations.ps1'          # les trois états
& 'C:\Projets\perfecoconsulting\automation-agent\validations.ps1' -Json    # pour une routine
```

Dernière ligne, toujours lisible sans interprétation :
`VALIDATIONS: ouvertes=<n> echues=<n> a_poser=<n>`

Code de sortie : `0` rien en attente · `2` quelque chose à mettre dans le brouillon ·
`3` **au moins un défaut à appliquer maintenant, avant de produire**.

Quand Jean-Michel tranche :

```powershell
& '...\validations.ps1' -Trancher -Id <id> -Decision "<sa décision>"
```

---

## Historique

- **12/09/2026** — création. Les deux règles, le registre `validations.json`, le script
  `validations.ps1`, et l'insertion des deux règles dans les 10 fiches de routines.
