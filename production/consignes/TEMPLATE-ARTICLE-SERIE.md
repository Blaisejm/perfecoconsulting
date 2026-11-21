# Template standard — Article de série PerfEco
# À utiliser pour chaque campagne hebdomadaire

---

## RÈGLES ÉDITORIALES OBLIGATOIRES

Sur chaque article (perfeco.nc ET perfsystemique.fr) :

| Élément | perfeco.nc | perfsystemique.fr |
|---------|-----------|------------------|
| Auteur | ✅ Jean-Michel Blaise, Fondateur PerfEco Consulting NC | ✅ Jean-Michel Blaise, Fondateur PerfEco Consulting NC |
| Date | ✅ Date de diffusion — toujours un mardi (ex: 30 juin 2026) | ✅ Date de diffusion |
| Série | ✅ "Série [Nom] · X/N" | ✅ "Série [Nom] · X/N" |
| Lien croisé | ✅ → vers perfsystemique.fr (version complète) | ✅ → vers perfeco.nc (version synthèse) |
| Navigation série | ✅ Article précédent / suivant | ✅ Article précédent / suivant |
| Canonical | ⚠️ pointe vers perfsystemique.fr | ✅ canonical propre |
| URL site | `https://www.perfeco.nc/` | `https://perfsystemique.fr/` |
| Email | `contact@perfeco.nc` | `contact@perfeco.nc` |

---

## STRUCTURE perfeco.nc (Astro)

```astro
---
import Base from '../../layouts/Base.astro';
import Nav from '../../components/Nav.astro';
import Footer from '../../components/Footer.astro';
---

<Base
  title="[TITRE SEO] — PerfEco"
  description="[DESCRIPTION 160 CAR MAX]"
  canonicalOverride="https://perfsystemique.fr/[SLUG-WP]/"
>
  <!-- ⚠️ OBLIGATOIRE : slug EN exact — sinon switcher FR/EN génère un 404 (bug corrigé 01/07/2026) -->
  <Nav langAlternate="/en/resources/[SLUG-EN]" />
  <main class="pt-16">

    <!-- Hero -->
    <section class="bg-navy-dark text-white py-20 px-4">
      <div class="max-w-3xl mx-auto">
        <div class="flex items-center gap-3 mb-4 flex-wrap">
          <span class="text-xs bg-teal/20 text-teal font-medium px-3 py-1 rounded-full">[THÈME 1]</span>
          <span class="text-xs bg-teal/20 text-teal font-medium px-3 py-1 rounded-full">[THÈME 2]</span>
          <time class="text-xs text-gray-400" datetime="[YYYY-MM-DD]">[DATE LISIBLE]</time>
        </div>
        <p class="text-sm text-amber-400 font-semibold mb-3 uppercase tracking-widest">Série [NOM SÉRIE] · [X]/[N]</p>
        <h1 class="text-3xl sm:text-4xl font-bold mb-6 leading-snug">[TITRE H1]</h1>
        <p class="text-gray-300 text-lg leading-relaxed">[CHAPÔ]</p>
        <!-- Auteur -->
        <div class="flex items-center gap-3 mt-8 pt-6 border-t border-white/10">
          <div>
            <p class="text-sm font-semibold text-white">Jean-Michel Blaise</p>
            <p class="text-xs text-gray-400">Fondateur — PerfEco Consulting NC</p>
          </div>
        </div>
      </div>
    </section>

    <!-- Bandeau version complète -->
    <div class="bg-amber-50 border-b border-amber-200 py-3 px-4">
      <div class="max-w-3xl mx-auto flex items-center gap-2 text-sm text-amber-800">
        <span>📖</span>
        <span>Cet article est une synthèse.</span>
        <a href="https://perfsystemique.fr/[SLUG-WP]/" target="_blank" rel="noopener" class="font-semibold underline hover:text-amber-900">
          Lire la version complète sur perfsystemique.fr →
        </a>
      </div>
    </div>

    <!-- Contenu -->
    <section class="py-16 px-4">
      <div class="max-w-3xl mx-auto prose prose-lg prose-gray">
        [CONTENU ARTICLE]

        <!-- Lien version approfondie (milieu ou fin d'article) -->
        <div class="not-prose bg-blue-50 border border-blue-200 rounded-xl p-6 my-8">
          <p class="text-sm font-semibold text-blue-900 mb-1">Version approfondie</p>
          <p class="text-sm text-blue-800 mb-3">La version complète avec analyses détaillées est disponible sur perfsystemique.fr.</p>
          <a href="https://perfsystemique.fr/[SLUG-WP]/" target="_blank" rel="noopener" class="inline-flex items-center gap-2 text-sm font-semibold text-blue-700 hover:text-blue-900 underline">
            Lire l'article complet sur perfsystemique.fr →
          </a>
        </div>
      </div>
    </section>

    <!-- Navigation série -->
    <section class="border-t border-gray-200 py-10 px-4">
      <div class="max-w-3xl mx-auto">
        <p class="text-xs font-semibold uppercase tracking-widest text-gray-400 mb-4">Série [NOM SÉRIE]</p>
        <div class="grid sm:grid-cols-2 gap-4">
          <!-- Article précédent (mettre opacity-50 + pas de lien si premier) -->
          <a href="/ressources/[SLUG-PRECEDENT]" class="bg-gray-50 hover:bg-gray-100 rounded-lg p-4 transition-colors">
            <p class="text-xs text-gray-500 mb-1">← Article précédent</p>
            <p class="text-sm font-medium text-gray-700">[TITRE ARTICLE PRÉCÉDENT]</p>
            <p class="text-xs text-gray-400 mt-1">Série · [X-1]/[N] · [DATE PRÉCÉDENTE]</p>
          </a>
          <!-- Article suivant (mettre opacity-50 si dernier) -->
          <a href="/ressources/[SLUG-SUIVANT]" class="bg-gray-50 hover:bg-gray-100 rounded-lg p-4 transition-colors">
            <p class="text-xs text-teal font-semibold mb-1">Article suivant →</p>
            <p class="text-sm font-medium text-gray-700">[TITRE ARTICLE SUIVANT]</p>
            <p class="text-xs text-gray-400 mt-1">Série · [X+1]/[N] · [DATE SUIVANTE]</p>
          </a>
        </div>
      </div>
    </section>

    <!-- CTA -->
    <section class="bg-navy-dark text-white py-16 px-4">
      <div class="max-w-2xl mx-auto text-center">
        <h2 class="text-2xl font-bold mb-4">[TITRE CTA]</h2>
        <p class="text-gray-300 mb-8">[TEXTE CTA]</p>
        <a href="/contact" class="inline-block bg-teal hover:bg-teal-dark text-white font-semibold px-8 py-3 rounded-lg transition-colors">
          Prendre contact →
        </a>
        <p class="text-gray-400 text-sm mt-4">contact@perfeco.nc — +687 73 08 75</p>
      </div>
    </section>

  </main>
  <Footer />
</Base>
```

---

## BLOC AUTEUR WordPress (HTML — à coller en tête d'article)

```html
<div style="display:flex; align-items:center; gap:16px; padding:16px 0; border-bottom:1px solid #e5e7eb; margin-bottom:32px;">
  <div>
    <p style="margin:0; font-weight:700; color:#111827;">Jean-Michel Blaise</p>
    <p style="margin:4px 0 0; font-size:13px; color:#6B7280;">Fondateur — PerfEco Consulting NC · <time datetime="[YYYY-MM-DD]">[DATE LISIBLE]</time></p>
    <p style="margin:4px 0 0; font-size:12px; color:#1E56A3; font-weight:600;">Série [NOM SÉRIE] · Article [X]/[N]</p>
  </div>
</div>
```

---

## LIEN CROISÉ WordPress → perfeco.nc (HTML)

```html
<div style="background:#f0f5ff; border:1px solid #c7d9f8; border-radius:8px; padding:14px 18px; margin-bottom:28px;">
  <p style="margin:0; font-size:13px; color:#163D78;">📌 Cet article est également disponible en version synthèse sur <a href="https://www.perfeco.nc/ressources/[SLUG-ASTRO]" style="color:#1E56A3; font-weight:600;">https://www.perfeco.nc/ →</a></p>
</div>
```

---

## NAVIGATION SÉRIE WordPress (HTML — à coller en fin d'article)

```html
<div style="border-top:1px solid #e5e7eb; padding-top:24px; margin-top:32px;">
<p style="font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:2px; color:#9CA3AF; margin-bottom:12px;">Série [NOM SÉRIE]</p>
<div style="display:grid; grid-template-columns:1fr 1fr; gap:12px;">
  <div style="background:#f0f5ff; border-radius:8px; padding:14px; border:1px solid #c7d9f8;">
    <p style="font-size:11px; color:#1E56A3; font-weight:700; margin:0 0 4px;">← Article précédent · [X-1]/[N]</p>
    <p style="font-size:13px; color:#163D78; font-weight:600; margin:0;">[TITRE PRÉCÉDENT]</p>
    <p style="font-size:11px; color:#6B7280; margin:4px 0 0;">[DATE PRÉCÉDENTE]</p>
  </div>
  <div style="background:#f0f5ff; border-radius:8px; padding:14px; border:1px solid #c7d9f8;">
    <p style="font-size:11px; color:#1E56A3; font-weight:700; margin:0 0 4px;">Article suivant · [X+1]/[N] →</p>
    <p style="font-size:13px; color:#163D78; font-weight:600; margin:0;">[TITRE SUIVANT]</p>
    <p style="font-size:11px; color:#6B7280; margin:4px 0 0;">[DATE SUIVANTE]</p>
  </div>
</div>
</div>
```

---

## CHECKLIST avant publication

- [ ] Auteur mentionné (Jean-Michel Blaise + titre)
- [ ] Date visible dans l'article
- [ ] Numéro de série (X/N) affiché
- [ ] Lien croisé perfeco.nc ↔ perfsystemique.fr présent
- [ ] Navigation série (précédent / suivant) en place
- [ ] Canonical perfeco.nc pointe vers perfsystemique.fr
- [ ] URL du site : `https://www.perfeco.nc/` (jamais `perfeco.nc` seul)
- [ ] Email : `contact@perfeco.nc`
- [ ] Toggle LinkedIn désactivé dans la popup WordPress avant programmation
- [ ] **Page FR** : `<Nav langAlternate="/en/resources/[SLUG-EN]" />` renseigné ← OBLIGATOIRE sinon 404
- [ ] **Page EN** : `<Nav langAlternate="/ressources/[SLUG-FR]" />` renseigné ← OBLIGATOIRE sinon 404
