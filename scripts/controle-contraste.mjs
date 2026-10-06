#!/usr/bin/env node
// ---------------------------------------------------------------------------
// CONTRÔLE DE CONTRASTE — règle nº 45
//
// POURQUOI CE CONTRÔLE EXISTE (07/10/2026)
//
// Le 06/10, l'orange du logo servait de couleur de texte sur tout le site :
// blanc sur orange à 2,80:1, orange sur blanc à 2,80:1, orange sur le bleu à
// 2,20:1. Personne ne l'avait vu en dix-huit mois de mise en ligne.
//
// En le corrigeant, le script qui a repris les 497 classes en a cassé deux
// autres : deux liens sont passés en BLANC SUR FOND CLAIR — 1,05:1, invisibles
// à l'œil — parce qu'il remontait les lignes du fichier source sans distinguer
// un bloc bleu VOISIN d'un bloc bleu PARENT. Le même piège a frappé trois fois
// de suite : en français, puis en anglais, puis sur les cartes de /contact.
//
// Ce qui les a trouvés à chaque fois, c'est la mesure du RENDU, jamais la
// relecture du code. D'où ce contrôle, et d'où le choix de lire dist/ et non
// src/ : une classe Tailwind ne dit rien du fond réel derrière elle, seul
// l'arbre des éléments le dit.
//
// CE QU'IL FAIT : il refuse une mise en ligne où un texte passerait sous le
// seuil de lisibilité AA (4,5:1, ou 3:1 pour les grands caractères).
//
// CE QU'IL NE FAIT PAS, et qu'il ne faut pas croire couvert :
//   - le texte posé sur une PHOTO. Le contrôle remonte jusqu'au premier fond
//     plein et ignore les images, exactement comme la mesure faite au
//     navigateur le 07/10. Les bandeaux d'accroche sont dans ce cas : leur
//     photo est à 25 % sous un dégradé, le fond retenu est le bleu de la
//     section. C'est l'hypothèse la plus favorable.
//   - les états de survol et de focus.
//   - la taille réelle à l'écran d'un visiteur qui a zoomé.
//
// Il lit dist/, donc il suppose `npm run build` déjà passé.
// ---------------------------------------------------------------------------

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import config from '../tailwind.config.mjs';

// Sans argument : les pages construites. Avec : un fichier ou un dossier
// precis — c'est ainsi qu'on lance le temoin.
const CIBLE = process.argv[2] || 'dist';
const SEUIL_NORMAL = 4.5;
const SEUIL_GRAND = 3.0;

// --- la palette -------------------------------------------------------------
// Les couleurs de marque viennent de tailwind.config.mjs : une seule source,
// comme pour le bleu. Les gris et les couleurs fonctionnelles sont celles de
// Tailwind, qui ne bougent pas.
const MARQUE = config.theme.extend.colors;
const aplatir = (prefixe, valeur, sortie) => {
  if (typeof valeur === 'string') { sortie[prefixe] = valeur; return; }
  for (const [k, v] of Object.entries(valeur)) {
    aplatir(k === 'DEFAULT' ? prefixe : `${prefixe}-${k}`, v, sortie);
  }
};
const COULEURS = {
  white: '#FFFFFF', black: '#000000',
  'gray-50': '#F9FAFB', 'gray-100': '#F3F4F6', 'gray-200': '#E5E7EB',
  'gray-300': '#D1D5DB', 'gray-400': '#9CA3AF', 'gray-500': '#6B7280',
  'gray-600': '#4B5563', 'gray-700': '#374151', 'gray-800': '#1F2937',
  'gray-900': '#111827', 'gray-950': '#030712',
  'green-50': '#F0FDF4', 'green-100': '#DCFCE7', 'green-200': '#BBF7D0',
  'green-600': '#16A34A', 'green-700': '#15803D', 'green-800': '#166534',
  'red-50': '#FEF2F2', 'red-100': '#FEE2E2', 'red-200': '#FECACA',
  'red-600': '#DC2626', 'red-700': '#B91C1C', 'red-800': '#991B1B',
};
for (const [k, v] of Object.entries(MARQUE)) aplatir(k, v, COULEURS);

// --- l'échelle de texte, également prise dans la configuration --------------
const TAILLES = {};
for (const [nom, def] of Object.entries(config.theme.extend.fontSize ?? {})) {
  const rem = parseFloat(Array.isArray(def) ? def[0] : def);
  TAILLES[nom] = rem * 16;
}
const TAILLES_PAR_DEFAUT = { xs: 12, sm: 14, base: 16, lg: 18, xl: 20, '2xl': 24, '3xl': 30, '4xl': 36, '5xl': 48, '6xl': 60, '7xl': 72, '8xl': 96, '9xl': 128 };
for (const [k, v] of Object.entries(TAILLES_PAR_DEFAUT)) if (!(k in TAILLES)) TAILLES[k] = v;

const GRAISSES = { 'font-thin': 100, 'font-light': 300, 'font-normal': 400, 'font-medium': 500,
                   'font-semibold': 600, 'font-bold': 700, 'font-extrabold': 800, 'font-black': 900 };

// --- couleur ---------------------------------------------------------------
const rgb = (hex) => {
  const h = hex.replace('#', '');
  return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
};
const composer = (dessus, alpha, dessous) =>
  dessus.map((c, i) => Math.round(c * alpha + dessous[i] * (1 - alpha)));
const luminance = ([r, g, b]) => {
  const c = [r, g, b].map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; });
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
};
const contraste = (a, b) => {
  const [h, l] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (h + 0.05) / (l + 0.05);
};

/** « teal/20 » -> { hex, alpha }. Rend null si la couleur est inconnue. */
const lireCouleur = (jeton) => {
  const [nom, opacite] = jeton.split('/');
  const hex = COULEURS[nom];
  if (!hex) return null;
  return { rgb: rgb(hex), alpha: opacite === undefined ? 1 : Number(opacite) / 100 };
};

// --- un analyseur HTML minimal ---------------------------------------------
// La sortie d'Astro est générée, régulière et bien formée : un analyseur de
// quelques dizaines de lignes suffit, et évite d'ajouter une dépendance au
// projet (il n'en a que trois). Il est validé plus bas par un témoin.
const VIDES = new Set(['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
                       'link', 'meta', 'source', 'track', 'wbr']);
// Contenu BRUT : ce qu'il y a dedans n'est pas du balisage. Il faut sauter
// jusqu'a la fermeture sans rien analyser au passage — un <script> qui contient
// la chaine « <script » serait sinon compte comme une vraie balise ouvrante, et
// tout le corps de la page resterait masque. C'est exactement ce qui s'est
// produit au premier essai : 56 fragments de texte pour 56 pages.
const BRUTS = new Set(['script', 'style', 'title', 'noscript', 'textarea']);
// Contenu balise, mais sans texte qui nous interesse.
const IGNORES = new Set(['head', 'svg', 'template']);

const entites = (s) => s
  .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<')
  .replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'")
  .replace(/&rarr;/g, '→').replace(/&mdash;/g, '—').replace(/&middot;/g, '·')
  .replace(/&[a-z]+;/g, ' ');

/** Appelle `visiter(texte, pile)` pour chaque fragment de texte visible. */
function parcourir(html, visiter) {
  const pile = [];
  let i = 0, ignoreProfondeur = 0;
  const re = /<\/?([a-zA-Z][a-zA-Z0-9-]*)((?:"[^"]*"|'[^']*'|[^>"'])*)>/g;
  let m;
  while ((m = re.exec(html)) !== null) {
    const texte = html.slice(i, m.index);
    i = re.lastIndex;
    if (!ignoreProfondeur && texte.trim()) visiter(entites(texte).trim(), pile);
    const balise = m[1].toLowerCase();
    const fermante = m[0][1] === '/';
    const autofermante = m[0].endsWith('/>') || VIDES.has(balise);
    if (BRUTS.has(balise) && !fermante && !autofermante) {
      const fin = html.toLowerCase().indexOf(`</${balise}`, re.lastIndex);
      if (fin === -1) break;
      const apres = html.indexOf('>', fin);
      re.lastIndex = apres === -1 ? html.length : apres + 1;
      i = re.lastIndex;
      continue;
    }
    if (BRUTS.has(balise)) continue;
    if (IGNORES.has(balise)) {
      if (!fermante && !autofermante) ignoreProfondeur++;
      else if (fermante && ignoreProfondeur) ignoreProfondeur--;
      continue;
    }
    if (autofermante) continue;
    if (fermante) { for (let k = pile.length - 1; k >= 0; k--) { if (pile[k].balise === balise) { pile.length = k; break; } } }
    else {
      const attrs = m[2] || '';
      const cls = (attrs.match(/\sclass="([^"]*)"/) || [])[1] || '';
      const cache = /\saria-hidden="true"/.test(attrs) || /\shidden(?=[\s>])/.test(attrs);
      pile.push({ balise, classes: cls.split(/\s+/).filter(Boolean), cache });
    }
  }
  const reste = html.slice(i);
  if (!ignoreProfondeur && reste.trim()) visiter(entites(reste).trim(), pile);
}

// --- l'état visuel déduit d'une pile d'éléments ----------------------------
// Les variantes responsives sont appliquées comme sur un écran large : c'est
// la largeur à laquelle la mesure de référence a été faite.
const VARIANTE = /^(sm|md|lg|xl|2xl):/;
const nettoyer = (c) => c.replace(VARIANTE, '');

function etat(pile) {
  let couleur = rgb('#111827');     // la couleur d'encre par défaut du site
  let fond = rgb('#FFFFFF');
  let taille = 16, graisse = 400;
  let invisible = false;

  for (const el of pile) {
    if (el.cache) invisible = true;
    let masque = false, demasque = false;
    for (const brut of el.classes) {
      const c = nettoyer(brut);
      const responsive = VARIANTE.test(brut);
      if (c === 'hidden') { if (responsive) masque = true; else masque = true; }
      if (responsive && ['block', 'flex', 'inline-flex', 'grid', 'inline-block', 'table'].includes(c)) demasque = true;
      if (c === 'sr-only' || c === 'opacity-0') invisible = true;

      let mm;
      if ((mm = c.match(/^bg-([a-z0-9-]+(?:\/\d+)?)$/))) {
        const v = lireCouleur(mm[1]);
        if (v) fond = v.alpha >= 1 ? v.rgb : composer(v.rgb, v.alpha, fond);
      }
      if ((mm = c.match(/^text-([a-z0-9-]+(?:\/\d+)?)$/))) {
        if (mm[1] in TAILLES) taille = TAILLES[mm[1]];
        else { const v = lireCouleur(mm[1]); if (v) couleur = v.alpha >= 1 ? v.rgb : composer(v.rgb, v.alpha, fond); }
      }
      if (c in GRAISSES) graisse = GRAISSES[c];
    }
    if (masque && !demasque) invisible = true;
  }
  return { couleur, fond, taille, graisse, invisible };
}

// --- le parcours des pages -------------------------------------------------
function pages(dir) {
  const out = [];
  for (const e of readdirSync(dir)) {
    const p = join(dir, e);
    if (statSync(p).isDirectory()) out.push(...pages(p));
    else if (e.endsWith('.html')) out.push(p);
  }
  return out;
}

if (!existsSync(CIBLE)) {
  console.error(`✘ ${CIBLE} est absent : lancez « npm run build » avant ce contrôle.`);
  process.exit(2);
}

const fichiers = statSync(CIBLE).isDirectory() ? pages(CIBLE) : [CIBLE];
const base = statSync(CIBLE).isDirectory() ? CIBLE : '.';
if (fichiers.length === 0) {
  console.error(`✘ aucune page trouvée dans ${CIBLE} — le contrôle n'a rien pu examiner.`);
  process.exit(2);
}

const fautes = [];
let textesExamines = 0;

for (const f of fichiers) {
  const html = readFileSync(f, 'utf8');
  parcourir(html, (texte, pile) => {
    if (texte.length < 2) return;
    const e = etat(pile);
    if (e.invisible) return;
    textesExamines++;
    const grand = e.taille >= 24 || (e.taille >= 18.66 && e.graisse >= 700);
    const seuil = grand ? SEUIL_GRAND : SEUIL_NORMAL;
    const c = contraste(e.couleur, e.fond);
    if (c + 1e-9 < seuil) {
      const hex = (v) => '#' + v.map((n) => n.toString(16).padStart(2, '0')).join('').toUpperCase();
      fautes.push({
        page: relative(base, f).split(sep).join('/'),
        texte: texte.slice(0, 48),
        couleur: hex(e.couleur), fond: hex(e.fond),
        taille: Math.round(e.taille), contraste: c.toFixed(2), seuil,
      });
    }
  });
}

console.log(`Contrôle de contraste — ${fichiers.length} page(s), ${textesExamines} fragment(s) de texte examinés.`);

// Mode témoin : on n'attend pas zéro, on attend le compte exact.
const attendu = process.env.CONTRASTE_ATTENDU ? Number(process.env.CONTRASTE_ATTENDU) : null;
if (attendu !== null) {
  const distincts = new Set(fautes.map((d) => `${d.couleur}|${d.fond}|${d.texte}`)).size;
  const ok = distincts === attendu;
  console.log(ok
    ? `✔ témoin : ${distincts} cas détectés, ${attendu} attendus.`
    : `✘ témoin : ${distincts} cas détectés, ${attendu} attendus — le contrôle a changé de comportement.`);
  if (!ok) for (const d of fautes) console.log(`    ${d.page} « ${d.texte} » ${d.couleur}/${d.fond} ${d.contraste}:1`);
  process.exit(ok ? 0 : 1);
}

if (fautes.length === 0) {
  console.log('✔ aucun texte sous le seuil de lisibilité.');
  process.exit(0);
}

console.error(`\n✘ ${fautes.length} texte(s) sous le seuil :\n`);
const vues = new Set();
for (const d of fautes) {
  const cle = `${d.couleur}|${d.fond}|${d.texte}`;
  if (vues.has(cle)) continue;          // le même texte revient sur chaque page
  vues.add(cle);
  console.error(`  ${d.page}`);
  console.error(`    « ${d.texte} »`);
  console.error(`    ${d.couleur} sur ${d.fond} — ${d.contraste}:1, il en faut ${d.seuil} (${d.taille} px)\n`);
}
console.error(`${fautes.length} occurrence(s), ${vues.size} cas distinct(s).`);
console.error("Un texte sous le seuil n'est pas « un peu pâle » : sur un téléphone en plein jour, il ne se lit pas.");
process.exit(1);
