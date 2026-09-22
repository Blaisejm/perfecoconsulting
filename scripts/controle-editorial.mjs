/**
 * Contrôle éditorial PerfEco — les règles de forme, rendues exécutables.
 *
 * POURQUOI CE SCRIPT (23/09/2026)
 * -------------------------------
 * Le compte des règles du 23/09 a établi que 17 règles sur 43 sont parfaitement
 * testables et que rien ne les teste. Toutes les règles éditoriales vivaient dans
 * des fichiers Markdown, qu'aucune machine ne lit. Ce script est le premier à en
 * exécuter trois :
 *
 *   1. RÈGLE nº 7  — un slogan s'énonce, il ne se déduit pas.  → BLOQUANT
 *   2. RÈGLE §6a   — un visuel se lit sans traduction.         → AVERTISSEMENT
 *   3. CHARTE      — couleurs, logo, taille du logo.           → BLOQUANT
 *
 * POURQUOI 2 N'EST QU'UN AVERTISSEMENT
 * « pilotage » appartient au vocabulaire de marque (« Le Rythme de Pilotage »).
 * Un contrôle qui crie au loup à chaque slide finit ignoré — leçon du 21/09 :
 * « un contrôle qui n'a pas tourné n'est ni un succès ni 32 fausses erreurs ».
 * On signale, on ne bloque pas, et on dit toujours combien de fichiers ont été
 * réellement examinés.
 *
 * USAGE
 *   node scripts/controle-editorial.mjs <fichiers...>     HTML de carrousel, JSON de file
 *   node scripts/controle-editorial.mjs --titre "..."     un slogan isolé, avant génération
 *
 * Sortie : code 1 si au moins une erreur bloquante, 0 sinon.
 */
import { readFileSync, statSync } from 'node:fs';
import { basename, extname } from 'node:path';

const ROUGE = '\x1b[31m', JAUNE = '\x1b[33m', VERT = '\x1b[32m', GRIS = '\x1b[90m', RAZ = '\x1b[0m';
const erreurs = [];
const avertissements = [];
let examines = 0;

const err = (fichier, regle, message, extrait) =>
  erreurs.push({ fichier, regle, message, extrait });
const avert = (fichier, regle, message, extrait) =>
  avertissements.push({ fichier, regle, message, extrait });

/* ─────────── RÈGLE nº 7 — un slogan s'énonce ─────────── */
// Marqueurs fermés. Chacun impose au lecteur une soustraction au lieu d'une affirmation.
const MARQUEURS_7 = [
  { re: /\bce\s+n['’]est\s+pas\b/i,        nom: "« ce n'est pas »" },
  { re: /\bn['’](est|sont)\s+pas\s+(un|une|le|la|les|des)\b/i, nom: '« n\'est pas un/une… »' },
  { re: /\bplut[oô]t\s+qu/i,               nom: '« plutôt que »' },
  { re: /\bmoins\b[^.!?]{2,40}\bque\b/i,   nom: '« moins … que »' },
  { re: /\bau\s+lieu\s+d/i,                nom: '« au lieu de »' },
  { re: /\bnon\s+pas\b/i,                  nom: '« non pas »' },
];
// Antithèse en deux temps : « Seul, on X. Ensemble, on Y. »
const ANTITHESE = /\b(seul|d['’]un\s+c[oô]t[ée]|avant)\b[^.!?]{5,70}[.!?]\s*\b(ensemble|de\s+l['’]autre|apr[eè]s|mais)\b/i;

// Antithèse par antonymes — « Les silos SÉPARENT… Les projets les RÉUNISSENT. »
// Uniquement À CHEVAL SUR UNE FRONTIÈRE DE PHRASE : c'est ce qui distingue une
// opposition en deux temps (à bannir) d'une affirmation double dans une seule
// proposition — « Moins de friction, plus d'énergie » affirme, elle n'oppose pas.
const ANTONYMES = [
  ['sépare', 'réunit'], ['séparent', 'réunissent'], ['divise', 'rassemble'],
  ['divisent', 'rassemblent'], ['éloigne', 'rapproche'], ['éloignent', 'rapprochent'],
  ['ralentit', 'accélère'], ['ralentissent', 'accélèrent'],
  ['complique', 'simplifie'], ['compliquent', 'simplifient'],
  ['coûte', 'rapporte'], ['ferme', 'ouvre'], ['ferment', 'ouvrent'],
  ['perd', 'gagne'], ['perdent', 'gagnent'], ['freine', 'libère'], ['freinent', 'libèrent'],
];

function antitheseParAntonymes(t) {
  const phrases = t.split(/[.!?]+/).map(p => p.trim().toLowerCase()).filter(Boolean);
  if (phrases.length < 2) return null;
  for (const [a, b] of ANTONYMES) {
    for (let i = 0; i < phrases.length - 1; i++) {
      const suite = phrases.slice(i + 1).join(' ');
      const ra = new RegExp(`\\b${a}\\b`), rb = new RegExp(`\\b${b}\\b`);
      if ((ra.test(phrases[i]) && rb.test(suite)) || (rb.test(phrases[i]) && ra.test(suite))) {
        return `${a} / ${b}`;
      }
    }
  }
  return null;
}

function regle7(texte, fichier) {
  const t = texte.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
  if (!t) return;
  for (const m of MARQUEURS_7) {
    if (m.re.test(t)) {
      err(fichier, 'nº 7', `Négation dans un titre — ${m.nom}. Un slogan affirme, il ne demande pas une soustraction.`, t.slice(0, 90));
      return;
    }
  }
  if (ANTITHESE.test(t)) {
    err(fichier, 'nº 7', "Antithèse en deux temps — trois opérations mentales pour une image lue en deux secondes.", t.slice(0, 90));
    return;
  }
  const paire = antitheseParAntonymes(t);
  if (paire) {
    err(fichier, 'nº 7', `Antithèse par opposition (${paire}) à cheval sur deux phrases — le sens naît de l'écart, au lieu d'être énoncé.`, t.slice(0, 90));
  }
}

/* ─────────── RÈGLE §6a — un visuel se lit sans traduction ─────────── */
// Mots qui n'existent que dans le conseil en organisation.
const JARGON = ['capacité', 'capacités', 'arbitrage', 'arbitrages', 'alignement',
                'alignements', 'levier', 'leviers', 'portage', 'transversalité',
                'référentiel', 'opérationnalisation'];

function regle6a(texte, fichier) {
  const t = texte.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim().toLowerCase();
  if (!t) return;
  const trouves = JARGON.filter(j => new RegExp(`\\b${j}\\b`, 'i').test(t));
  if (trouves.length) {
    avert(fichier, '§6a', `Jargon de pilotage sur un visuel : ${trouves.join(', ')}. Nommer une chose concrète — des dossiers, des heures, des bras.`, t.slice(0, 90));
  }
}

/* ─────────── CHARTE — couleurs, logo ─────────── */
const PALETTES = [
  { nom: 'principale', couleurs: ['#001d9f', '#fbaa16'] },
  { nom: 'V2',         couleurs: ['#163d78', '#fbaa16'] },
];

function charte(html, fichier) {
  const bas = html.toLowerCase();
  const ok = PALETTES.some(p => p.couleurs.every(c => bas.includes(c)));
  if (!ok) {
    err(fichier, 'charte', `Aucune palette complète trouvée. Attendu #001D9F + #FBAA16, ou #163D78 + #FBAA16 pour le gabarit V2.`, null);
  }
  const logos = [...html.matchAll(/<img[^>]*logo-perfeco[^>]*>/gi)];
  if (!logos.length) {
    err(fichier, 'charte', "Logo absent. Il est obligatoire sur tous les visuels et ne se remplace jamais par du texte.", null);
  } else {
    for (const l of logos) {
      if (/src\s*=\s*["']file:\/\//i.test(l[0])) {
        err(fichier, 'charte', "Logo chargé en file:/// — toujours l'URL absolue https://www.perfeco.nc/logo-perfeco.svg.", l[0].slice(0, 80));
      } else if (!/src\s*=\s*["']https:\/\//i.test(l[0])) {
        err(fichier, 'charte', "Logo chargé par un chemin relatif — toujours l'URL absolue https.", l[0].slice(0, 80));
      }
    }
    // Tailles : 130 px sur fond clair, 150 px sur fond sombre. Non négociable.
    const hauteurs = [...html.matchAll(/logo-zone\s+img\s*\{[^}]*height:\s*(\d+)px/gi)].map(m => +m[1]);
    const hors = hauteurs.filter(h => h < 130);
    if (hors.length) {
      err(fichier, 'charte', `Logo à ${hors.join(', ')} px. Minimum 130 px sur fond clair, 150 px sur fond sombre — plusieurs retours de Jean-Michel sur ce point.`, null);
    }
  }
}

/* ─────────── Extraction des textes à contrôler ─────────── */
// Sur un carrousel, seuls les TITRES portent la règle nº 7 : pas les étiquettes,
// pas le corps des items, pas les listes.
function titresHtml(html) {
  const out = [];
  const motifs = [
    /<h1[^>]*class="[^"]*main-title[^"]*"[^>]*>([\s\S]*?)<\/h1>/gi,
    /<h2[^>]*class="[^"]*cta-title[^"]*"[^>]*>([\s\S]*?)<\/h2>/gi,
    /<h2(?![^>]*class="[^"]*cta-title)[^>]*>([\s\S]*?)<\/h2>/gi,
    /<p[^>]*class="[^"]*subtitle[^"]*"[^>]*>([\s\S]*?)<\/p>/gi,
  ];
  for (const re of motifs) for (const m of html.matchAll(re)) out.push(m[1]);
  return out;
}

function traiterHtml(chemin) {
  const html = readFileSync(chemin, 'utf8');
  const nom = basename(chemin);
  examines++;
  for (const t of titresHtml(html)) { regle7(t, nom); regle6a(t, nom); }
  charte(html, nom);
}

function traiterJson(chemin) {
  const brut = readFileSync(chemin, 'utf8').replace(/^﻿/, '');
  let d; try { d = JSON.parse(brut); } catch { return; }
  const nom = basename(chemin);
  examines++;
  const msg = d?.social_post?.message;
  if (typeof msg === 'string' && msg.trim()) {
    // Sur un POST, la règle nº 7 ne s'applique qu'à la première ligne — l'accroche.
    regle7(msg.split('\n').find(l => l.trim()) || '', nom + ' (accroche)');
    // Densité d'emoji : au moins un marqueur visuel toutes les 3 lignes non vides.
    const lignes = msg.split('\n').filter(l => l.trim());
    const avecMarqueur = lignes.filter(l => /\p{Extended_Pictographic}|[▪️①-⑳1-9]️?⃣/u.test(l)).length;
    if (lignes.length >= 6 && avecMarqueur / lignes.length < 0.33) {
      avert(nom, 'emojis', `Densité de marqueurs faible : ${avecMarqueur} lignes sur ${lignes.length}. La règle demande un marqueur par idée.`, null);
    }
  }
}

/* ─────────── Entrée ─────────── */
const args = process.argv.slice(2);
if (!args.length) {
  console.error('Usage : node scripts/controle-editorial.mjs <fichiers...> | --titre "slogan"');
  process.exit(2);
}

if (args[0] === '--titre') {
  const titre = args.slice(1).join(' ');
  examines = 1;
  regle7(titre, '(titre fourni)');
  regle6a(titre, '(titre fourni)');
} else {
  for (const a of args) {
    let st; try { st = statSync(a); } catch { console.error(`${JAUNE}Introuvable : ${a}${RAZ}`); continue; }
    if (!st.isFile()) continue;
    const ext = extname(a).toLowerCase();
    if (ext === '.html') traiterHtml(a);
    else if (ext === '.json') traiterJson(a);
  }
}

/* ─────────── Rapport ─────────── */
console.log(`\nContrôle éditorial — ${examines} fichier(s) réellement examiné(s).`);

for (const a of avertissements) {
  console.log(`${JAUNE}  ⚠ ${a.fichier} — règle ${a.regle}${RAZ}`);
  console.log(`     ${a.message}`);
  if (a.extrait) console.log(`     ${GRIS}« ${a.extrait} »${RAZ}`);
}
for (const e of erreurs) {
  console.log(`${ROUGE}  ✖ ${e.fichier} — règle ${e.regle}${RAZ}`);
  console.log(`     ${e.message}`);
  if (e.extrait) console.log(`     ${GRIS}« ${e.extrait} »${RAZ}`);
}

if (!examines) {
  console.log(`${JAUNE}Aucun fichier examiné — ce n'est pas un succès. Vérifier les chemins fournis.${RAZ}`);
  process.exit(2);
}
if (erreurs.length) {
  console.log(`\n${ROUGE}${erreurs.length} erreur(s) bloquante(s), ${avertissements.length} avertissement(s).${RAZ}\n`);
  process.exit(1);
}
console.log(`${VERT}Aucune erreur bloquante${RAZ}${avertissements.length ? ` — ${avertissements.length} avertissement(s).` : '.'}\n`);
