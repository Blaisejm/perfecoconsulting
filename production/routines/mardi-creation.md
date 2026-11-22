# Routine cloud — CRÉATION du mardi : carrousel 6 slides + variante Facebook + articles (MODE OMBRE)

> Étape 5 de la diffusion 100 % cloud (22/11/2026, Jean-Michel : « accélère la migration des routines
> de création »). Transposition de la routine locale `mardi-carrousel-creation` (étapes 4.0 à 4.9),
> pour tourner dans GitHub Actions / routine cloud claude.ai, PC éteint.
>
> **MODE OMBRE : tu ne publies rien et tu ne touches pas à la file réelle.** Tu produis dans `sortie/`,
> puis tu pousses UNIQUEMENT une branche `ombre/mardi-<date>` (étape finale). Jamais `main`, jamais de
> webhook, jamais d'appel en écriture aux API LinkedIn, Facebook ou WordPress.
>
> **CE DÉPÔT EST PUBLIC.** Les semaines de l'axe **Institutions** obéissent à des règles éditoriales
> confidentielles (plateforme, lignes rouges). Elles te sont données **dans la consigne de ta routine**,
> jamais dans le dépôt. **N'écris JAMAIS ces règles, ni aucun nom, mandat, partenaire ou dossier qu'elles
> citent, dans un fichier, un commit, un message de commit ou la branche.** Elles servent à contrôler
> ce que tu écris, pas à être recopiées.

## Étape 0 — Cible, sujet, historique, améliorations

1. **Cible** : celle que la consigne de ta routine impose. À défaut : la prochaine échéance `mardi`
   de `automation-agent/publications.json` sans file (`automation-queue/mardi.json` ou
   `automation-queue/mardi-W<SS>-pret.json` portant cette date), statut ni `publie`, ni `annule`, ni
   `non_publie`. Heure NC : `TZ=Pacific/Noumea date`. Mardi férié → signale-le (règle : mardi → lundi).
2. **Sujet** : `libelle` et `sujet` de l'échéance, et son `axe` (`institutions` ou série). Ne choisis
   jamais un sujet toi-même.
3. **Historique** : les entrées `mardi` passées du registre, et la file de la semaine précédente
   (`git log -p -- automation-queue/mardi.json`) : jamais « même indicateur ET même angle ».
4. **Améliorations** : `python3 automation-agent/ameliorations.py lister --format mardi` (et `--format
   tous` s'il existe) ; applique chaque point ouvert et dis lesquels dans le rapport.

## Étape 1 — Le carrousel (6 slides) et la variante Facebook

- **Modèle** : `production/gabarits/carousel-le-projet-dabord.html` (épisode Institutions 1, zone sûre
  Facebook dans son bloc `/* ZONE SÛRE FACEBOOK */`). Copie-le dans `sortie/visuel/carousel-<slug>.html`
  et réécris CHAQUE slide, variante Facebook comprise (son balisage est propre : un remplacement global
  ne la couvre pas).
- Structure : 1 couverture · 2 constat · 3 contenu + photo · 4 cadre · 5 diagnostic + photo · 6 conclusion
  (pas d'appel commercial si la consigne de la routine dit « sans CTA »).
- **Photos : banque d'images validées** `production/images/banque/` (pas de génération). Trois photos,
  aucune utilisée dans les 8 dernières publications (`production/images/banque/USAGE.json`, ajoute tes
  lignes). Regarde chaque photo (Read) : groupe de 3 à 6 personnes visible. Jamais `production/images/personnages/`.
- **Typographie et lisibilité** (règles de Jean-Michel, non négociables) : couverture `.main-title`
  64 px / 900, `.subtitle` 24 px / 600 ; logo 150 px sur fond sombre (filtre blanc), 130 px sur fond
  clair, toujours `https://www.perfeco.nc/logo-perfeco.svg` ; marge latérale ≥ 96 px ; `&nbsp;` dans les
  nombres et avant `%` ; aucun emoji dans le HTML ; encadré conseil dominant (`.callout p` 29 px / 800 /
  `#001D9F`, bordure 9 px) ; une seule négation par phrase ; un visuel se lit sans traduction (pas de
  « capacité, pilotage, arbitrage, alignement, levier » ; ni Go/No-Go, PMO, note de concept, reste à
  charge, portage) ; `<br>` aux frontières de sens, jamais un petit mot isolé ; aucune slide à plus de
  40 % de blanc ; couleurs `#001D9F`, `#FBAA16`, `#163D78`, `#EDF4FF` seulement.
- **Zone sûre (couverture ET variante Facebook)** : titre et logo dans le carré central, 170 px libres en
  haut et en bas, marge latérale ≥ 176 px (la mosaïque LinkedIn coupe 140 px de chaque côté), titre
  centré, un seul titre dominant, sous-titre en blanc plein ou en or.
- **Le groupe reste visible sous le voile** (point A-2026-11-22-01, relevé de nouveau sur l'ombre du
  01/12) : le dégradé bleu ne couvre jamais toute la photo. Garde au moins un tiers de l'image à moins de
  35 % d'opacité, là où sont les visages, et vérifie sur le PNG (et sur l'aperçu carré) que 3 personnes au
  moins se distinguent. Sinon, éclaircis le dégradé ou décale `object-position`.
- **Export** (Puppeteer ; s'il manque : `npm install --no-save puppeteer`) :
  `node production/outils/export-slides.cjs sortie/visuel/carousel-<slug>.html sortie/public/slides/W<SS> 01-couverture-<slug>,02-…,03-…,04-…,05-…,06-…,00-facebook-<slug>`
  (`<SS>` = semaine ISO du mardi cible ; adapte les noms à l'ordre des `.slide` du fichier).
- **Contrôles** : relis les 7 PNG (Read) ; puis `python3 -X utf8 automation-agent/apercu-recadrage.py
  <png> <dossier>` sur `01-couverture-…` et `00-facebook-…`, et relis les aperçus carré et mosaïque.
  Corrige et réexporte tant qu'un titre, un logo ou un sous-titre est coupé ou collé à un bord.

## Étape 2 — Les textes

- **Post LinkedIn Company + Facebook** (`social_post.message`) et **post profil perso**
  (`linkedin_profil.message`, qui accompagne le carrousel en document PDF). Registre conseil : reconnaître
  ce que le dirigeant a déjà tenté, dire pourquoi ça ne suffit pas sans accuser, UNE recommandation ;
  clôture en positif. Emoji en tête de chaque idée ; coordonnées chacune sur sa ligne (📞 +687 73 08 75 /
  📩 contact@perfeco.nc / 🌐 perfeco.nc) ; 3 à 5 hashtags. Règles : `production/consignes/regles-editoriales.md`.
- **Articles perfeco.nc FR et EN** (~800 mots) : `sortie/site/src/pages/ressources/<slug-fr>.astro` et
  `sortie/site/src/pages/en/resources/<slug-en>.astro`, sur le modèle EXACT des articles de l'épisode 1
  (`src/pages/ressources/le-projet-dabord-largent-ensuite.astro` et
  `src/pages/en/resources/the-project-first-the-funding-second.astro`) ; plus l'entrée en tête du tableau
  `articles[]` de `src/pages/ressources.astro` et `src/pages/en/resources.astro` (copies modifiées dans
  `sortie/site/…`). L'anglais est une vraie version, pas une traduction mot à mot.
- **Article perfsystemique.fr** : bloc `wordpress` de la file (`titre`, `slug` sans accent et libre —
  vérifie `https://perfsystemique.fr/wp-json/wp/v2/posts?slug=<slug>` = `[]` —, `extrait` accentué,
  `contenu_html` 800 à 1 200 mots en `<h2>`/`<p>`/`<ul>`, `categorie_id` 10 ou 11, `tags`). Si la consigne
  de ta routine dit que ce type d'article ne va pas sur perfsystemique.fr, produis-le quand même en ombre
  et signale l'écart en tête du rapport : la décision revient à Jean-Michel.

## Étape 3 — Relecture FR (tous les textes)

`production/consignes/relecture-fr-perfeco.SKILL.md` : LanguageTool sur chaque texte et chaque titre de
slide (`node scripts/relecture-fr.mjs --texte "…"`) ; relecteur indépendant (sous-agent qui ne voit que le
texte et `production/consignes/relecture-fr-exemples.md`) sur le post Company, le post perso, le chapeau
des articles et l'article WordPress ; **retouche et remesure jusqu'à 4 partout** (3 tours au plus).

## Étape 4 — La file (dans sortie/)

`sortie/automation-queue/mardi-W<SS>-pret.json`, écrit avec Python `json.dump(..., ensure_ascii=False, indent=2)` :

```json
{
  "_comment": "FICHIER DE STAGING — diffusion mardi <date>. À basculer dans mardi.json après la publication du mardi en cours (perfeco-rappel-quotidien, étape 1quinquies).",
  "semaine": "W<SS>",
  "date_prevue": "AAAA-MM-JJ",
  "perfeco_nc_url_fr": "https://www.perfeco.nc/ressources/<slug-fr>",
  "perfeco_nc_url_en": "https://www.perfeco.nc/en/resources/<slug-en>",
  "social_post": { "message": "<post Company + Facebook>", "image_url": "https://www.perfeco.nc/slides/W<SS>/00-facebook-<slug>.png" },
  "linkedin_profil": { "type": "carousel", "message": "<post perso>", "image_urls": ["https://www.perfeco.nc/slides/W<SS>/01-…png", "… 6 URL, dans l'ordre"] },
  "wordpress": { "titre": "…", "slug": "…", "extrait": "…", "contenu_html": "…", "categorie_id": 11, "tags": ["…"] }
}
```

## Étape 5 — Contrôle, puis rapport

Contrôle : date = mardi de la cible ; 7 PNG présents, relus, aperçus vérifiés ; 6 `image_urls` dans
l'ordre ; articles FR et EN et index ; bloc `wordpress` complet ; relecture ≥ 4 partout ; **aucune règle
ni aucun nom confidentiel dans les fichiers produits** (relis-les dans ce but).

Rapport : cible et axe ; textes (Company, perso) ; articles (titres, slugs, mots) ; relecture (notes
finales) ; visuel (photos choisies, aperçus) ; améliorations appliquées ; points d'attention.

## Étape finale — Pousser la branche ombre (jamais main)

```bash
B="ombre/mardi-<date_prevue>"
git checkout -b "$B"
mkdir -p automation-queue public/slides production/sorties-ombre
cp sortie/automation-queue/*.json automation-queue/
cp -r sortie/public/slides/* public/slides/
cp sortie/visuel/*.html production/sorties-ombre/
cp -r sortie/site/src/* src/
git add automation-queue public/slides production/sorties-ombre src production/images/banque/USAGE.json
git commit -m "ombre : création cloud mardi du <date_prevue> — NE PAS FUSIONNER sans comparaison"
git push -u origin "$B"
```
Si le push est refusé, dis-le avec le message exact : jamais `main` pour contourner.

## MODE PRODUCTION (depuis le 22/11/2026, Jean-Michel : « Oui, en production »)

Quand la consigne de la routine dit **MODE PRODUCTION**, l'étape finale ci-dessus (branche ombre) est
REMPLACÉE par celle-ci. Tout le reste (étapes 0 à 5) est inchangé.

**0. Rien à produire ?** Si la cible du registre est à plus de 10 jours, ou si une file
(`automation-queue/mardi.json` ou `automation-queue/mardi-W<SS>-pret.json`) porte déjà cette date,
**ne produis rien** : fais seulement les contrôles (date, textes, bloc `wordpress`, 7 images en HTTP 200,
pages article FR et EN en HTTP 200 ou présentes sur main).

**1. Où écrire.** N'écris `automation-queue/mardi.json` directement QUE si sa `date_prevue` est déjà
passée (heure NC) ; sinon écris le staging `automation-queue/mardi-W<SS>-pret.json` avec le champ
`_comment` de l'étape 4. Jamais par-dessus une file dont la date est aujourd'hui ou à venir.

**2. Quoi ajouter dans le commit.** La file ; les 7 PNG + le carré dans `public/slides/W<SS>/` ; les HTML
dans `production/sorties/<date>/` (photos en chemin `../../images/banque/…`) ; les articles
`src/pages/ressources/<slug-fr>.astro` et `src/pages/en/resources/<slug-en>.astro` ; leurs entrées en
tête de `articles[]` dans `src/pages/ressources.astro` et `src/pages/en/resources.astro` (insertion
ciblée, jamais réécriture du fichier) ; tes lignes de `production/images/banque/USAGE.json` ; dans
`automation-agent/publications.json`, **édition ciblée** de l'entrée `<date>-mardi` seulement
(`semaine`, `source`, une note « produit par la routine cloud creation-mardi-cloud le <date> ») :
remplacements de texte dans le bloc de cette entrée, puis `json.loads` sur le fichier entier avant
d'écrire. **Jamais** de `json.dump` du fichier entier.

**3. Champs propres au cloud.** `linkedin_profil.titre_document` (titre du PDF du profil perso, sans
emoji, ≤ 60 caractères) et `social_post.facebook_image_url` (le carré). **Pas** de `wordpress_post_id` :
l'article est planifié par `publish-mardi-article-wordpress.yml` quand la file arrive dans `mardi.json`,
et les contrôles le retrouvent par son slug. Si la consigne de ta routine autorise perfsystemique.fr pour
l'axe de la semaine, le bloc `wordpress` est obligatoire.

**4. Relecteurs : minimum 4 partout** (post Company, post perso, chapeau des articles, article
WordPress, l'accroche comprise). Tant qu'une note est inférieure à 4, retouche et relance (3 tours au
plus ; au-delà, mets en file quand même mais signale-le en tête du rapport).

**5. Pousser sur main, proprement.**
```bash
git add <fichiers listés ci-dessus> && git commit -m "creation-mardi-cloud : file du mardi <date> — <épisode>"
for i in 1 2 3; do git pull --rebase origin main && git push origin HEAD:main && break; sleep 30; done
```
En cas de conflit au rebase : `git rebase --abort`, n'écrase rien, dis-le dans le rapport.

**6. Contrôle relu sur origin/main.** `git fetch origin` puis `git show origin/main:<fichier de file>`
relu en JSON (date, longueurs, 6 `image_urls`, `facebook_image_url`, `titre_document`, slug WordPress
libre). Attends le déploiement du site (jusqu'à 10 minutes) : les 7 images, le carré et les deux pages
article doivent répondre **HTTP 200**. Relis enfin tes fichiers poussés : **aucune règle ni aucun nom
confidentiel**.

## Pièces jointes du brouillon Gmail

Le connecteur Gmail refuse tout appel de plus de 4,2 Mo (≈ 3,1 Mo de fichiers). Ne joins jamais les PNG
d'origine : joins des **aperçus JPEG** de la couverture et de la variante Facebook, 800 px de large,
qualité 80 (Pillow, ou `apercu-recadrage.py` puis conversion), et donne les liens des PNG sur la branche.

## Variante Facebook CARRÉE et logo agrandi (22/11/2026, Jean-Michel — points A-2026-11-22-08 et 09)

Facebook affiche mal le 4:5 (image rétrécie entre deux bandes, logo minuscule). Pour CHAQUE publication
qui part sur Facebook (y compris la republication du samedi, qui reprend la file du jeudi) :
1. Produis un carré 1200×1200 avec le générateur (photo de groupe en haut, bandeau bleu, logo à 240 px) :
   `python3 production/outils/carre-facebook.py --photo ../../images/banque/<photo>.jpg --titre "<ligne 1>|<ligne 2>" --accent 1 [--libelle "…"] [--chiffre "…"] [--sous-titre "…"] --position "50% 35%" --sortie-html production/sorties/<date>/carre-facebook-<slug>.html`
   puis `node production/outils/export-slides.cjs production/sorties/<date>/carre-facebook-<slug>.html public/slides/W<SS> 00-facebook-carre-<slug>`.
   Un seul titre dominant ; le chiffre, s'il y en a un, reste une ligne d'appui. Mêmes textes que le visuel
   (relus par LanguageTool). Regarde le PNG : groupe visible, logo net, rien de coupé.
2. Ajoute dans la file `social_post.facebook_image_url` = `https://www.perfeco.nc/slides/W<SS>/00-facebook-carre-<slug>.png`.
   LinkedIn garde `image_url` (4:5) ; Facebook prend le carré (publication directe, Make sans Facebook).
3. **Logo** sur tous les visuels : au moins 18 % de la largeur (≈ 220 px sur 1200), dans la zone sûre ;
   vérifie-le sur les aperçus recadrés.
