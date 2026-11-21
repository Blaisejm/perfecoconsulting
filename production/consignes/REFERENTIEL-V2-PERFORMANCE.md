# Référentiel « Communication V2 — Performance »

**Décidé par Jean-Michel le 15/09/2026.** PerfEco ouvre une **campagne dédiée « Performance »**,
avec sa propre ligne éditoriale et son propre gabarit visuel. Elle occupe un créneau fixe :
**le jeudi, chaque semaine**.

> ⚠️ **Lire la section 1 avant tout.** Une alternance « une semaine sur deux » a été envisagée puis
> abandonnée le 15/09. Le rythme est identique chaque semaine. Toute mention résiduelle d'alternance,
> de « parité ISO » ou de « semaine V2 » ailleurs dans le dispositif est périmée.

Sources : `Comm & Marketing/Plan_communication_PerfEco_Performance-14-09-26.docx`,
`Comm & Marketing/Publications_PerfEco_Septembre_Octobre_2026.docx`,
visuels de référence `Comm & Marketing/Communation V2 - septembre W 34/` (10 PNG).

---

## 0. Où lire le calendrier (sans ouvrir un fichier technique)

**Demande de Jean-Michel du 15/09/2026** : *« ton calendrier des publications doit être sauvegardé
en dur sur le cloud, il y a trop de doute à ce niveau »*.

| Ce que vous cherchez | Où |
|---|---|
| **Le calendrier, en clair** | OneDrive › `PerfEco Consulting NC` › `Comm & Marketing` › **`CALENDRIER-PUBLICATIONS-PerfEco.docx`** |
| La même chose en Markdown | `Perfeco-Social-Media/CALENDRIER-PUBLICATIONS.md` |
| La source technique (machines) | `automation-agent/publications.json` — versionnée sur GitHub |

### Si le Word refuse de s'ouvrir

Vérifié le 22/09/2026 : **ce n'est pas le fichier.** Il est régénéré à chaque routine et reste un
.docx valide. Le symptôme vient de OneDrive, qui garde le fichier « en ligne uniquement » sur
l'appareil depuis lequel on essaie de l'ouvrir — d'autant plus facilement qu'il est réécrit
plusieurs fois par semaine.

**Correctif, confirmé par Jean-Michel :** clic droit sur le fichier dans l'explorateur →
**« Toujours conserver sur cet appareil »**.

Avant de chercher plus loin, ce test tranche en dix secondes : si `python-docx` ouvre le fichier
côté disque, le document est sain et le problème est un problème d'accès, pas de contenu.

**Le document Word est régénéré, jamais écrit à la main.** Il est reconstruit depuis le registre
**à la fin de chaque routine**, par `trace-routine.ps1` — le seul point de passage obligatoire de
toutes les routines. Il ne peut donc pas diverger de ce qui est réellement programmé.

Pour corriger une date ou un sujet : modifier `publications.json`, puis
`python automation-agent/calendrier-lisible.py`. Modifier le Word directement ne sert à rien : il
sera écrasé au prochain passage d'une routine.

---

## 1. Où vit cette politique : le créneau du JEUDI

**Décision finale de Jean-Michel, 15/09/2026 :** *« on publie toutes les semaines la même chose »*.

| Jour | Contenu | Rattachement |
|---|---|---|
| Mardi | post long, carrousel 6 slides | série éditoriale (Série 2, puis Série 3…) |
| **Jeudi** | **post court, visuel unique** | **campagne dédiée Performance — cette politique** |
| Vendredi | post court | veille éco |

**Il n'y a AUCUNE alternance.** Deux versions d'un mécanisme « une semaine sur deux » ont été posées
le 15/09 (d'abord « preuve → résultat », puis « semaine V2 / semaine série sur parité ISO ») et
**toutes deux supprimées le même jour**. Si une trace subsiste quelque part, c'est un résidu.

Conséquences :

- **La Série 2 garde son rythme hebdomadaire** — 5/8 au 29/09, 6/8 au 06/10, 7/8 au 13/10,
  8/8 au 20/10. Aucun étalement.
- **La campagne dédiée démarre le jeudi 01/10** par le manifeste « Du cap aux résultats »
  (choix de Jean-Michel), et se termine le **jeudi 03/12** avec la 10ᵉ publication.
- **Le vendredi n'est pas concerné** : la veille éco garde format, sourçage et gabarit.
- **Le mardi n'est pas concerné** : carrousel 6 slides, charte #001D9F / #FBAA16, inchangé.

### Sur quels canaux part la campagne (arbitrage du 15/09/2026)

| Jour | LinkedIn Company | LinkedIn perso | Facebook | Sites |
|---|---|---|---|---|
| Mardi — série | ✅ | ✅ carrousel | ✅ | ✅ perfeco.nc FR+EN + perfsystemique.fr |
| **Jeudi — campagne** | ✅ | ✅ | ❌ | — |
| Vendredi — veille éco | ✅ | ✅ | ✅ | — |
| **Samedi — reprise du jeudi** | — | — | ✅ | — |

**Le post du jeudi arrive bien sur Facebook — le samedi à 15h30**, en reprise
(`publish-samedi-republication-facebook.yml`, actif depuis le 18/08/2026). Une seule fois, au lieu
de deux : jusqu'ici Facebook recevait le jeudi *et* le samedi, doublon relevé le 23/08.

Facebook publie donc **mardi, vendredi et samedi**. Le profil perso publie **mardi, jeudi et
vendredi** — la règle des 48 h d'espacement, posée le 17/08, a été **explicitement abandonnée** par
Jean-Michel le 15/09 : *« les trois jours, et la règle des 48 h est abandonnée »*.

✅ **Le filtre Make est en place**, créé par Jean-Michel le 15/09/2026 et **vérifié par l'API**
(run #24 de `check-avant-publication.yml`, au vert) : scénario 6916780, condition `1. semaine` →
**Does not contain** → `NOFB`.

*Deux enseignements de cette mise en place, utiles pour la prochaine fois :* le filtre est posé sur
le lien **HTTP → Facebook Pages** plutôt que Router → HTTP — c'est fonctionnel, la route s'arrête
avant de publier, seul un téléchargement d'image inutile subsiste le jeudi. Et surtout : **le
« Save » de la fenêtre de filtre ne suffit pas.** Il affiche le filtre sur le diagramme, mais tant
que le SCÉNARIO n'est pas enregistré, l'API ne le voit pas — c'est précisément ce qu'a attrapé le
run #23, en échec, alors que l'écran semblait correct.

### Affectation des jeudis — ordre naturel 1 → 10

Les 10 publications sont affectées dans `publications.json` (champ `libelle` :
« Campagne dédiée N/10 — <territoire> »). **Le registre fait foi** — ne jamais choisir un sujet
dans son coin ni réordonner la banque.

| Jeudi | # | Publication | Territoire |
|---|---|---|---|
| **01/10** | 1 | **Du cap aux résultats** — manifeste, ouvre la campagne | Du cap à la mise en œuvre |
| 08/10 | 2 | Des équipes alignées sur les mêmes priorités | Mieux travailler ensemble |
| 15/10 | 3 | Un reporting qui aide réellement à décider | Piloter avec une information fiable |
| 22/10 | 4 | Les coûts invisibles de l'organisation *(visuel déjà produit)* | Simplifier le fonctionnement |
| 29/10 | 5 | Traiter la cause des problèmes récurrents | Simplifier le fonctionnement |
| 05/11 | 6 | Numériser sans ajouter de complexité | Simplifier le fonctionnement |
| 12/11 | 7 | Aider les collaborateurs à produire un travail plus fiable | Mieux travailler ensemble |
| 19/11 | 8 | Être prêt face au COMEX ou au siège | Piloter avec une information fiable |
| 26/11 | 9 | Relier les gains rapides à une amélioration durable | Prouver les résultats |
| **03/12** | 10 | Commencer par une lecture claire (diagnostic 60 min) — **dernière** | Prouver les résultats |

### ⏰ Alerte de fin de campagne

**Demande de Jean-Michel du 15/09/2026 : être prévenu deux semaines avant la fin.**

`mercredi-creation` (ÉTAPE 0quater) recompte à chaque jeudi le nombre de publications de campagne
encore `prevu` dans le registre. **Dès qu'il en reste 2 ou moins, l'alerte part en tête du brouillon
Gmail** avec la date de la dernière et la question : reconduire une banque de 10, enchaîner sur une
autre campagne, ou rendre le créneau à un autre usage ?

Avec l'affectation ci-dessus, l'alerte tombe d'elle-même vers le **19/11/2026**. Ce n'est pas une
tâche planifiée : c'est un compteur recalculé depuis le registre — rien à maintenir, et il reste
juste même si un jeudi est décalé. *(Les tâches one-time de ce dispositif ont échoué 4 fois sur 4,
toutes supprimées le 06/09/2026.)*

### Aucune exception dans le calendrier

Sur demande de Jean-Michel (15/09/2026), **toutes les semaines suivent le même schéma**, y compris
celle du 26 au 30/10 qui portait auparavant une « semaine Institutions » sur ses trois créneaux.
Vérifié sur 10 semaines consécutives : **aucun écart**.

**Où est passée la campagne Institutions.** Le créneau du mardi est défini comme « post long /
**série** » — or Institutions *est* une série (1/4 à 4/4). Elle occupe donc les mardis libérés par
la fin de la Série 2 :

| Mardi | Institutions |
|---|---|
| 27/10 | I1 — Le projet d'abord, l'argent ensuite *(contenu déjà largement produit)* |
| 03/11 | I2 — à produire |
| 10/11 | I3 — à produire |
| 17/11 | I4 — à produire |

⚠️ **Deux contenus de I1 sont mis de côté** : le post court du jeudi 29/10 (« le coût de la
troisième année ») et le radar financements du vendredi 30/10. Ces deux créneaux appartiennent
désormais à la campagne dédiée et à la veille éco. Ils restent disponibles dans
`calendrier-editorial/2026-10-27-SEMAINE-INSTITUTIONS-I1.md` si vous voulez les replacer.

### Les dates viennent de moi, pas du document

Précision de Jean-Michel (15/09/2026) : **les 10 publications n'ont pas de date imposée.** Le
calendrier du document source (17/09 → 20/10) est ignoré. Les créneaux retenus — les jeudis, du
01/10 au 03/12, dans l'ordre naturel — sont un choix éditorial, révisable à tout moment dans le
registre.

*Raisons de ce choix :* un rythme hebdomadaire régulier est plus lisible qu'un calendrier à trous ;
l'ordre naturel fait ouvrir la campagne par le manifeste, comme le prévoit le document ; et démarrer
le 01/10 laisse partir sans les bousculer les trois échéances déjà en file (17/09, 18/09, 22/09).

## 2. Ce que change la campagne dédiée (et ce qu'elle ne change pas)

### Positionnement

> Les contenus ne doivent plus commencer par une liste de prestations. Ils doivent partir d'une
> situation vécue par un dirigeant ou une équipe, montrer le résultat attendu, puis expliquer les
> conditions qui l'ont rendu possible.

**Le client reste le premier acteur du résultat.** PerfEco est partenaire de méthode, de
préparation et de pilotage — jamais le sauveur caché.

- **Promesse** : Transformer la stratégie en résultats.
- **Accroche média** : Du cap aux résultats.
- **Signature** : PerfEco — La performance maîtrisée au quotidien.

### Formule éditoriale de référence

> Situation observée → conséquence pour l'organisation → méthode de travail →
> résultat attendu ou constaté → invitation à échanger.

### Structure obligatoire d'un contenu V2

1. Partir d'une situation précise que le lecteur reconnaît immédiatement.
2. Nommer la difficulté sans dramatiser ni mettre les personnes en cause.
3. Montrer le changement recherché dans le travail ou dans le pilotage.
4. Expliquer brièvement la méthode utilisée par PerfEco **et les équipes**.
5. Apporter une preuve vérifiable, ou préciser l'indicateur qui permettra de mesurer le résultat.
6. Terminer par une question utile, une invitation à échanger ou une proposition de diagnostic.

### Les cinq territoires éditoriaux

Chaque contenu V2 appartient à **un seul** de ces territoires :

| Territoire | Sujet |
|---|---|
| Du cap à la mise en œuvre | Traduction des priorités en décisions, responsabilités, calendrier |
| Mieux travailler ensemble | Coordination direction / support / opérations |
| Piloter avec une information fiable | KPI, reporting, marges, cash, risques, qualité des données |
| Simplifier le fonctionnement | Processus, outils, automatisation, réduction de la complexité |
| Prouver les résultats | Effets mesurés, retours d'expérience, progression |

### Ce qui NE change pas

Ces règles restent valables sur les trois créneaux (mardi, jeudi, vendredi), sans exception :

- **Registre conseil « médecin »** (17/08) — reconnaître ce qui a déjà été tenté, expliquer
  pourquoi ça ne suffit pas sans accuser, **une seule** recommandation priorisée, clôture positive.
  La structure V2 ci-dessus en est une déclinaison, pas un remplacement.
- **Principe éditorial management** (04/08) — parler au lecteur-manager, jamais du chiffre pour
  le chiffre ; toujours un levier actionnable.
- **Vérification des chiffres à la source** — un chiffre non retrouvé à la source est un chiffre
  qu'on n'utilise pas. Et : *distinguer un résultat constaté, un objectif à atteindre et un
  bénéfice potentiel.*
- **Emoji sur les textes réseaux** (LinkedIn / Facebook), jamais dans le HTML du visuel.
- **Registre central `publications.json`**, verrou, traçabilité, anti-doublon Gmail, règle J-8.

---

## 3. Gabarit visuel V2

Fichier de référence : `images-library/linkedin-carousel/gabarit-v2-performance.html`
Export : `outils-ia/perfeco-publisher-mcp/export-v2.cjs`

### Décision de charte (15/09/2026)

Les deux documents se contredisaient sur la palette :

- le plan de communication impose violet **#4E0686** + orange **#FF3600** ;
- le document de publications dit **explicitement remplacer** ces codes par le bleu/orange du site.

Les visuels de référence donnent raison au second. **Couleurs mesurées directement sur les PNG :
navy #14407F, orange #F77D1E.**

**Arbitrage de Jean-Michel : on transpose le gabarit V2 dans la charte PerfEco existante**, pour
ne pas faire coexister deux chartes. La transposition est quasi indolore : le navy de référence
#14407F est à deux doigts du **#163D78** déjà présent dans la charte.

| Élément | Référence V2 | **Retenu (charte PerfEco)** |
|---|---|---|
| Bandeau | #14407F | **#163D78** |
| Accent (filet, arc) | #F77D1E | **#FBAA16** |
| Titre | blanc | blanc |
| Format | 1254×1254 carré | **1200×1500 (4:5)** — cohérent avec le pipeline existant et conforme à la règle « 1080×1350 » du document |

### Anatomie

- **Photo** pleine page, `object-position: center 22%` — situation de travail crédible en NC.
- **Bandeau bas** #163D78, hauteur 478 px, **bord supérieur courbe** montant vers la droite (SVG).
- **Voile** très léger au-dessus du bandeau pour la jonction photo/bandeau — jamais de texte posé
  directement sur la photo.
- **Titre** en capitales, deux graisses : ligne 1 `62px / 900`, ligne 2 `56px / 400`.
- **Filet d'accent** #FBAA16, 190×9 px, sous le titre.
- **Coin bas-droit** : pastille blanche à grand rayon + arc #FBAA16 + **logo 120 px**.
- Pas de numéro de slide, pas de badge de série, pas d'URL, pas de téléphone.

### Règles photo

- **3 à 5 personnes**, diversité multiculturelle Pacifique — jamais une personne seule.
- Personnes **en situation de travail réelle** : décider, expliquer, contrôler, coordonner,
  résoudre. Écarter les scènes de bureau génériques et les poignées de main.
- Ancrage NC visible quand c'est possible (lagon, montagnes, végétation) sans tomber dans la
  carte postale.
- **Aucun texte, logo, chiffre ou graphique dans l'image générée** — tout le texte vient du HTML.

### Points de vigilance (repris du plan de communication)

- Ne jamais présenter PerfEco comme le sauveur caché d'un dirigeant ou d'une équipe.
- Pas de bulle de pensée suggérant que le client dissimule l'accompagnement reçu.
- Ne pas représenter le siège métropolitain comme un juge et le dirigeant local comme un
  subordonné cherchant son approbation.
- Ne pas promettre une organisation parfaite ni un résultat garanti sans éléments vérifiables.
- Ne pas diminuer le mérite des collaborateurs.

---

## 4. Banque de contenus — les 10 publications

**Le registre `publications.json` reste maître.** Les dates du document source (17/09 → 20/10) ne
s'appliquent pas : elles entraient en collision avec des contenus déjà en file, avec le férié du
24/09 et avec l'annulation décidée le 03/09. Les 10 publications occupent les **jeudis, dans leur
ordre naturel**, du 01/10 au 03/12 (table en §1).

| # | Jeudi | Sujet | Territoire |
|---|---|---|---|
| 1 | 01/10 | Du cap aux résultats — la promesse PerfEco | Du cap à la mise en œuvre |
| 2 | 08/10 | Des équipes alignées sur les mêmes priorités | Mieux travailler ensemble |
| 3 | 15/10 | Un reporting qui aide réellement à décider | Piloter avec une information fiable |
| 4 | 22/10 | Les coûts invisibles de l'organisation | Simplifier le fonctionnement |
| 5 | 29/10 | Traiter la cause des problèmes récurrents | Simplifier le fonctionnement |
| 6 | 05/11 | Numériser sans ajouter de complexité | Simplifier le fonctionnement |
| 7 | 12/11 | Aider les collaborateurs à produire un travail plus fiable | Mieux travailler ensemble |
| 8 | 19/11 | Être prêt face au COMEX ou au siège | Piloter avec une information fiable |
| 9 | 26/11 | Relier les gains rapides à une amélioration durable | Prouver les résultats |
| 10 | 03/12 | Commencer par une lecture claire (diagnostic 60 min) | Prouver les résultats |

⚠️ **Publication 2 — proximité à surveiller à la rédaction.** « Des équipes alignées sur les mêmes
priorités » (jeudi 08/10) traite un terrain voisin de l'épisode 4/8 « Faire descendre les priorités »
diffusé le **mardi 22/09**, seize jours plus tôt. Les deux restent à leur date ; c'est **l'angle**
qui doit différer. Rappel de la règle du 03/09 : c'est la conjonction « même indicateur ET même
angle » qui bloque, pas le sujet voisin.

*Angle distinct à tenir :* le 22/09 traitait **le trajet descendant** d'une priorité (comment elle
arrive en bas). Le 08/10 doit traiter **l'accord horizontal** — plusieurs services qui interprètent
différemment la même priorité, et ce qui les remet d'accord. Ne pas réutiliser le chiffre 56 %/27 %.

### Appels à l'action

- Quel écart observez-vous aujourd'hui entre vos priorités et leur mise en œuvre ?
- Quel reporting vous aide réellement à prendre une décision ?
- Si cette situation existe dans votre organisation, PerfEco peut vous aider à la qualifier lors
  d'un premier échange.
- **Diagnostic stratégique 60 minutes** — ✅ **offre validée par Jean-Michel le 15/09/2026**,
  utilisable comme appel à l'action. Confidentiel, conduit directement par PerfEco, le dirigeant
  repart avec une lecture structurée et deux à trois pistes concrètes.

---

## 5. Contrôles avant diffusion d'un contenu V2

À passer en plus des contrôles habituels :

- [ ] Le public est-il clairement identifié (un rôle, une situation) ?
- [ ] La situation est-elle crédible en Nouvelle-Calédonie ou dans le Pacifique ?
- [ ] Le lien entre stratégie, mise en œuvre et résultat est-il visible (au moins deux maillons) ?
- [ ] Le client reste-t-il l'acteur du résultat ?
- [ ] La preuve est-elle honnête — chiffre vérifié à la source, bénéfice non mesuré présenté
      comme un objectif ?
- [ ] La prochaine action est-elle claire ?
- [ ] Le visuel respecte-t-il #163D78 / #FBAA16, le logo officiel et le gabarit ?
- [ ] Une seule idée, reliée au passage de la stratégie aux résultats ?

---

## 6. Mesure

Le rapport du mardi (`perfeco-rapport-dimanche`) compare l'engagement des **trois créneaux** —
série (mardi), campagne dédiée (jeudi), veille éco (vendredi) — à mesure **J+7 uniquement**
(règle du 18/08 : toute impression de moins de 7 jours est provisoire).

**Seuil : ne rien conclure avant 4 semaines complètes mesurées à J+7**, soit vers la fin octobre
2026, la campagne démarrant le 01/10. Avant cela, écrire « donnée insuffisante » plutôt
qu'extrapoler — une décision éditoriale a déjà été prise sur une analyse fausse le 16/08/2026.

Lecture attendue, au-delà des impressions : *le créneau qui crée de la visibilité est-il celui qui
déclenche des échanges qualifiés ?*
