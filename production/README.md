# production/ — ce dont la création a besoin pour tourner PC éteint

Étape 4 de la diffusion 100 % cloud (22/11/2026, accord de Jean-Michel : « tu continues la
migration des tâches planifiées »). Copie des outils et consignes qui vivaient sur le PC
(OneDrive, `Perfeco-Social-Media/`), pour que les routines de création tournent dans
GitHub Actions.

**Ce dépôt est PUBLIC.** N'entre ici que ce qui peut être lu par tous : gabarits visuels,
outils, règles éditoriales, exemples de relecture, personnages générés. Rien d'interne :
ni prospects, ni arbitrages, ni données personnelles, ni comptabilité, ni jetons.

| Dossier | Contenu | Source sur le PC |
|---|---|---|
| `gabarits/` | carrousels HTML, gabarit V2 Performance (`gabarit-v2-performance.html`), variante Facebook zone sûre (bloc `/* ZONE SÛRE FACEBOOK */` de `carousel-le-projet-dabord.html`) | `images-library/linkedin-carousel/` |
| `images/banque/` | **banque d'images validées** (choix de Jean-Michel du 22/11/2026, pas de génération sauf demande) : 49 photos de groupe déjà publiées, compressées en JPEG ≤ 1400 px, **toutes contrôlées le 22/11/2026 : 3 à 6 personnes, multiculturel Pacifique**. `USAGE.json` : qui a utilisé quoi (pas de réemploi sur 8 publications) | `images-library/linkedin-carousel/*-01.png` + 2 groupes de `personnages/` |
| `images/personnages/` | portraits et groupes de référence des personnages. **Hors charte pour un visuel** : 7 portraits individuels et un groupe de 2 (`groupe-consultant-client-01`), relevé A-2026-11-22-01. Ne pas utiliser en fond de visuel | `images-library/personnages/` |
| `outils/export-slides.cjs` | export Puppeteer des slides en PNG, **chemins en arguments** | `outils-ia/perfeco-publisher-mcp/export-slides.cjs` et `export-v2.cjs` |
| `outils/generate-image.mjs` | génération d'image (gpt-image-1), sortie dans `production/images/` ; exige le secret `OPENAI_API_KEY` | `outils-ia/perfeco-publisher-mcp/generate-image.mjs` |
| `consignes/` | référentiel V2, règles éditoriales, relecture FR (skill + exemples de calibrage), personnages, stratégie de diffusion des images, gabarits d'article, banque de visuels V2 | `base-connaissance/`, `templates/`, racine |

Déjà dans le dépôt, à leur place historique (non dupliqués) : `automation-agent/apercu-recadrage.py`,
le registre des améliorations `automation-agent/ameliorations-publications.json` et
`automation-agent/ameliorations.py` (lu en ÉTAPE 0-amélioration), `scripts/relecture-fr.mjs`.

Les anciens visuels de couverture (≈ 160 Mo de PNG déjà publiés) ne sont PAS copiés : un
gabarit sert de structure, chaque publication apporte son image. Quelques gabarits pointent
donc encore vers une couverture absente ; l'export l'arrête net (contrôle des images).

Restent PRIVÉS, hors de ce dépôt : transcriptions Whisper, registre des validations
nominatif, notes de prospection, comptabilité Broussan, compte de service GA4.

Essai : `.github/workflows/essai-production.yml` exporte un gabarit dans GitHub Actions.

`routines/` : consignes des routines de création cloud (routine claude.ai, choix de Jean-Michel),
en MODE OMBRE tant qu'un cycle conforme n'a pas été comparé à la routine locale : la sortie part
sur une branche `ombre/<format>-<date>`, jamais sur `main`.

Écartée de la banque : `w28-cover-comex-pacifique` (≈ 7 personnes, au-delà de la charte).
