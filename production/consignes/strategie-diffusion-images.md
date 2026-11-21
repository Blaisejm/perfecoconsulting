# Stratégie de diffusion images — PerfEco

Workflow de production et distribution des visuels sur tous les supports PerfEco.

---

## Principes fondateurs

1. **Générer une fois, diffuser partout** — chaque image produite alimente plusieurs supports
2. **Bibliothèque centralisée** — toutes les images dans `images-library/` + médiathèque WordPress
3. **Personnages cohérents** — les 6 personnages PerfEco reviennent sur tous les supports (reconnaissance de marque)
4. **Ton "Benetton pro"** — diversité Pacifique, attitude détendue, crédible niveau COMEX

---

## Chaîne de production

```
1. IDÉE / SUJET
       ↓
2. PROMPT DALL-E (depuis personnages-perfeco.md)
       ↓
3. GÉNÉRATION via outil generate_image (MCP)
       ↓
4. SAUVEGARDE locale images-library/ + WordPress (optionnel)
       ↓
5. VALIDATION visuelle
       ↓
6. DIFFUSION multi-formats
```

---

## Formats par canal et personnage recommandé

| Canal | Format demandé | Paramètre DALL-E | Personnages prioritaires |
|-------|---------------|-----------------|--------------------------|
| LinkedIn carrousel (slide) | 1 080 × 1 350 px | `portrait` | Sophie, Raphaël, Marc |
| LinkedIn post image | 1 200 × 627 px | `landscape` | Tous |
| Facebook post | 1 080 × 1 080 px | `square` | Kévin, Sophie, Raphaël |
| Site perfeco.nc — hero article | 1 200 × 630 px | `landscape` | Marc + 1 personnage local |
| Site perfeco.nc — vignette | 600 × 600 px | `square` | Tous |
| Presse / print | 2 048 px+ | `portrait` hd | Sophie ou Raphaël |

---

## Réutilisation des images

Une image générée peut être utilisée sur :
- LinkedIn (format original portrait)
- Facebook (recadrée en carré via Canva ou outil)
- Site web (recadrée en paysage)
- Newsletter
- Présentation client

→ Nommer les fichiers avec le format : `[prénom]-[contexte]-[numéro].png`
  Exemples : `sophie-comex-01.png`, `marc-reunion-terrasse-01.png`, `raphael-bureau-vue-mer-01.png`

---

## Règles de cohérence des personnages

Pour que le même personnage soit reconnaissable entre deux générations DALL-E :
- Toujours utiliser le prompt complet archivé dans `personnages-perfeco.md`
- Ajouter des détails spécifiques de scène EN PLUS du prompt de base (ne jamais remplacer)
- Conserver le même style photographique (`85mm lens, natural light, editorial business photography`)

---

## Fréquence de production recommandée

| Cadence | Volume images |
|---------|--------------|
| Semaine type | 6-8 images (1-2 carrousels + posts) |
| Lancement thème | 12-15 images (carrousel + variantes) |
| Budget mensuel estimé | ~$10-15 (DALL-E 3 HD) |

---

## Workflow carrousel LinkedIn (6 slides)

Pour chaque carrousel :
1. Slide 1 (couverture) : 1 personnage en situation + titre fort — format portrait
2. Slides 2-5 (contenu) : personnage en action liée au thème — format portrait
3. Slide 6 (CTA) : 2 personnages en échange (consultant + dirigeant) — format portrait
4. Texte post LinkedIn : rédigé et publié via outil `publish_linkedin_post` (MCP)
5. Images : attachées manuellement dans LinkedIn lors de la publication

---

## Thèmes visuels par personnage

| Personnage | Scènes idéales |
|------------|----------------|
| Sophie | Salle de réunion, présentation COMEX, bureau vitré vue Nouméa |
| Raphaël | Bureau exécutif, terrasse vue mer, poignée de main stratégique |
| Mei-Lin | Dashboard financier, laptop avec graphiques, réunion technique |
| Marc | Terrasse ou lobby, discussion informelle, paper board stratégique |
| Kévin | Site opérationnel, debout en mouvement, équipe terrain |
| Nora | Espace collaboratif, discussion d'équipe, atelier participatif |

---

## Archivage et traçabilité

Chaque image générée est sauvegardée avec :
- Fichier PNG dans `images-library/[sous-dossier]/[nom].png`
- Prompt source dans `personnages-perfeco.md` (section du personnage)
- Upload optionnel dans WordPress media (URL permanente disponible)

---

*Mise à jour : 18/06/2026 — intégration DALL-E 3 via MCP perfeco-publisher*
