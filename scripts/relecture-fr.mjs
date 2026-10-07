/**
 * Relecture FR PerfEco — couche MÉCANIQUE de la skill `relecture-fr-perfeco`.
 *
 * POURQUOI CE SCRIPT (07/10/2026)
 * -------------------------------
 * Demande de Jean-Michel : « les textes ne sont pas toujours bien compréhensibles ou
 * adaptés ou percutants en FR ». controle-editorial.mjs vérifie la FORME des visuels
 * (charte, négations, coupures) ; rien ne vérifiait la langue des posts eux-mêmes.
 *
 * Deux contrôles, de nature différente :
 *
 *   1. LANGUE (LanguageTool, API publique, niveau « picky ») → BLOQUANT
 *      grammaire, accords, orthographe, typographie. Ce sont des fautes, pas des goûts.
 *   2. LISIBILITÉ (règles locales)                            → avertissement
 *      phrases trop longues, jargon de conseil, plus d'une négation par phrase,
 *      antithèses (« au lieu de », « plutôt que »), mots creux.
 *      Ce sont des signaux pour le relecteur indépendant, pas des verdicts.
 *
 * Le jugement (« est-ce clair, est-ce percutant ? ») n'est PAS ici : il est fait par
 * l'agent relecteur de la skill. Un script ne sait pas dire si une phrase porte.
 *
 * USAGE
 *   node scripts/relecture-fr.mjs automation-queue/jeudi-W41-pret.json [autres.json]
 *   node scripts/relecture-fr.mjs --texte "Une phrase à vérifier."
 *   node scripts/relecture-fr.mjs --json …          sortie structurée (pour la skill)
 *
 * SORTIE : code 0 = aucune faute de langue ; 1 = au moins une faute ;
 *          2 = LanguageTool injoignable → contrôle NON EXÉCUTÉ (jamais un succès).
 */
import { readFileSync } from 'node:fs';
import { basename } from 'node:path';

const LT_URL = 'https://api.languagetool.org/v2/check';
const args = process.argv.slice(2);
const enJson = args.includes('--json');
const ROUGE = '\x1b[31m', JAUNE = '\x1b[33m', VERT = '\x1b[32m', GRIS = '\x1b[90m', RAZ = '\x1b[0m';

/* ─────────── Entrées ─────────── */
const textes = [];
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--json') continue;
  if (a === '--texte') { textes.push({ source: '--texte', texte: args[++i] || '' }); continue; }
  const j = JSON.parse(readFileSync(a, 'utf8').replace(/^﻿/, ''));
  const m = j?.social_post?.message;
  if (!m) { console.error(`${GRIS}${a} : pas de social_post.message — ignoré${RAZ}`); continue; }
  textes.push({ source: basename(a), texte: m });
}
if (!textes.length) { console.error('Usage : node scripts/relecture-fr.mjs <fichier.json…> | --texte "…"'); process.exit(1); }

/* ─────────── Ce que LanguageTool ne doit pas lire ─────────── */
// Hashtags, coordonnées, URLs : ni du français à corriger, ni des fautes.
function corpsRedige(t) {
  return t.split('\n')
    .filter(l => !/^\s*#\S/.test(l))                        // ligne de hashtags
    .filter(l => !/(@|www\.|https?:\/\/|\+687)/.test(l))     // coordonnées
    .join('\n');
}
// Règles LanguageTool écartées : bruit connu sur nos textes, pas des fautes.
const REGLES_IGNOREES = new Set([
  'WHITESPACE_RULE',        // doubles espaces autour des emoji
  'FRENCH_WHITESPACE',      // espace fine insécable avant « : » — LinkedIn la rend mal
  'APOS_TYP',               // apostrophe droite vs courbe : indifférent à l'écran
  'TIRET',                  // tiret cadratin d'incise : choix de style assumé
]);
// « 1er », « 2e » : LanguageTool réclame les exposants (1ᵉʳ, 2ᵉ). Correct en typographie
// soignée, mais rendu irrégulier sur LinkedIn et Facebook — l'usage courant l'emporte.
const PREFIXES_IGNORES = ['grammalecte_g2__typo_ordinaux'];
// Noms propres et sigles du territoire que le dictionnaire ignore. Tout mot ENTIÈREMENT en
// capitales (IEOM, DAF, CAFAT, COMEX…) est en plus accepté d'office : un sigle n'est pas une faute.
const LEXIQUE = new Set(['Isee', 'PerfEco', 'Nouméa', 'Dumbéa', 'Païta', 'Koné', 'Lifou', 'Maré',
  'Ouvéa', 'Calédonie', 'calédonien', 'calédonienne', 'calédoniens', 'calédoniennes', 'Enercal',
  'Eramet', 'Tukumuli', 'Medef', 'agios', 'Make', 'LinkedIn']);
const estSigleOuLexique = m => /^[A-ZÀ-Ý0-9&-]{2,}$/.test(m) || LEXIQUE.has(m);
// Ce qui BLOQUE : une faute (orthographe, grammaire, accord, confusion de mots).
// Ce qui AVERTIT : le style (répétition, calque, anglicisme) — un choix, pas une erreur.
// ⚠️ Les règles françaises de LanguageTool sont presque toutes en issueType « uncategorized » :
// c'est la CATÉGORIE qui dit s'il s'agit d'une faute (vérifié le 07/10/2026 — « vous avez pris »
// pour « prises » sortait en simple avertissement tant qu'on ne regardait que l'issueType).
const TYPES_BLOQUANTS = new Set(['misspelling', 'grammar', 'typographical']);
const CATEGORIES_BLOQUANTES = new Set(['TYPOS', 'GRAMMAR', 'CAT_GRAMMAIRE', 'CAT_HOMONYMES_PARONYMES',
  'CAT_TYPOGRAPHIE', 'CONFUSED_WORDS', 'CASING', 'CAT_ELISION', 'CAT_TOURS_CRITIQUES']);
const estBloquant = r => r.issueType !== 'style' &&
  (TYPES_BLOQUANTS.has(r.issueType) || CATEGORIES_BLOQUANTES.has(r.category.id));

/* ─────────── Lisibilité : signaux pour le relecteur ─────────── */
// Jargon de conseil interdit sur les visuels (règle §6 du 19/08) — toléré dans le post
// s'il est rare, signalé s'il s'accumule.
const JARGON = ['capacité', 'levier', 'leviers', 'alignement', 'arbitrage', 'arbitrages',
  'synergie', 'synergies', 'transverse', 'transversalité', 'opérationnaliser', 'impactant',
  'enjeux', 'parties prenantes', 'gouvernance', 'pilotage', 'paradigme', 'holistique',
  'proactif', 'proactive', 'optimiser', 'valeur ajoutée', 'performance durable'];
const CREUX = ['réellement', 'véritablement', 'vraiment', 'clairement', 'concrètement',
  'en effet', 'il est important de', 'il convient de', 'force est de constater', 'au final',
  'globalement', 'en quelque sorte'];
const ANTITHESE = [/\bau\s+lieu\s+d/i, /\bplut[oô]t\s+qu/i, /\bnon\s+pas\b/i, /\bce\s+n['’]est\s+pas\b/i];

function phrases(t) {
  return t.replace(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}]/gu, ' ')
    .split(/(?<=[.!?…])\s+|\n+/).map(s => s.trim()).filter(s => s.split(/\s+/).length >= 3);
}
function lisibilite(t) {
  const sig = [];
  const ps = phrases(t);
  for (const p of ps) {
    const mots = p.split(/\s+/).length;
    if (mots > 25) sig.push({ type: 'phrase longue', detail: `${mots} mots`, extrait: p });
    const neg = (p.match(/\b(ne|n['’])\s*\S+\s+(pas|plus|jamais|rien|personne|aucun|aucune|guère)\b/gi) || []).length;
    if (neg > 1) sig.push({ type: 'plusieurs négations', detail: `${neg} dans la phrase`, extrait: p });
    for (const re of ANTITHESE) if (re.test(p)) sig.push({ type: 'antithèse / négation', detail: String(re), extrait: p });
  }
  const bas = t.toLowerCase();
  const jargon = JARGON.filter(w => bas.includes(w));
  if (jargon.length >= 2) sig.push({ type: 'jargon', detail: jargon.join(', '), extrait: '' });
  const creux = CREUX.filter(w => bas.includes(w));
  if (creux.length) sig.push({ type: 'mots creux', detail: creux.join(', '), extrait: '' });
  const moy = ps.length ? Math.round(ps.reduce((s, p) => s + p.split(/\s+/).length, 0) / ps.length) : 0;
  return { signaux: sig, phrases: ps.length, mots_par_phrase: moy };
}

/* ─────────── LanguageTool ─────────── */
async function languageTool(t) {
  const corps = corpsRedige(t);
  const r = await fetch(LT_URL, {
    method: 'POST',
    body: new URLSearchParams({ text: corps, language: 'fr', level: 'picky' }),
    signal: AbortSignal.timeout(30000),
  });
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  const j = await r.json();
  return j.matches
    .filter(m => !REGLES_IGNOREES.has(m.rule.id))
    .filter(m => !PREFIXES_IGNORES.some(p => m.rule.id.startsWith(p)))
    .filter(m => !(m.rule.issueType === 'misspelling' && estSigleOuLexique(corps.substr(m.offset, m.length))))
    .map(m => ({
      bloquant: estBloquant(m.rule),
      regle: m.rule.id, categorie: m.rule.category.id, message: m.message,
      extrait: corps.substr(m.offset, m.length),
      contexte: m.context.text,
      suggestions: m.replacements.slice(0, 3).map(x => x.value),
    }));
}

/* ─────────── Exécution ─────────── */
const rapport = [];
let fautes = 0, nonExecute = false;
for (const { source, texte } of textes) {
  let langue = null, erreurLT = null;
  try { langue = await languageTool(texte); fautes += langue.filter(m => m.bloquant).length; }
  catch (e) { erreurLT = e.message; nonExecute = true; }
  rapport.push({ source, caracteres: [...texte].length, langue, erreurLT, ...lisibilite(texte) });
}

if (enJson) {
  console.log(JSON.stringify({ examines: rapport.length, fautes, non_execute: nonExecute, rapport }, null, 2));
} else {
  for (const r of rapport) {
    console.log(`\n── ${r.source} — ${r.caracteres} car., ${r.phrases} phrases, ${r.mots_par_phrase} mots/phrase en moyenne`);
    if (r.erreurLT) console.log(`${ROUGE}  ✖ LanguageTool injoignable (${r.erreurLT}) — contrôle de langue NON EXÉCUTÉ${RAZ}`);
    else if (!r.langue.length) console.log(`${VERT}  ✔ Langue : aucune faute${RAZ}`);
    else for (const m of r.langue)
      console.log(`${m.bloquant ? ROUGE + '  ✖ ' : JAUNE + '  ⚠ style · '}${m.regle}${RAZ} ${m.message}\n    « ${m.extrait} » → ${m.suggestions.join(' / ') || '—'}  ${GRIS}${m.contexte}${RAZ}`);
    for (const s of r.signaux)
      console.log(`${JAUNE}  ⚠ ${s.type}${RAZ} (${s.detail})${s.extrait ? `\n    ${GRIS}${s.extrait}${RAZ}` : ''}`);
  }
  console.log(`\n${rapport.length} texte(s) examiné(s) — ${fautes} faute(s) de langue${nonExecute ? ' — ⚠ contrôle NON EXÉCUTÉ sur au moins un texte' : ''}.`);
}
// exitCode plutôt que process.exit() : sous Node 24 / Windows, quitter pendant la fermeture
// des connexions de fetch() fait planter libuv (assertion UV_HANDLE_CLOSING, code 127) —
// une routine lirait alors un échec là où le contrôle a réussi. Constaté le 07/10/2026.
process.exitCode = nonExecute ? 2 : fautes ? 1 : 0;
