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
 *   RÈGLE nº 7      — un slogan s'énonce, il ne se déduit pas.   → BLOQUANT
 *   RÈGLE §1        — coupures de ligne au niveau de la phrase.  → BLOQUANT
 *   RÈGLE §2        — épaisseur autant que taille.               → BLOQUANT
 *   RÈGLE §4        — le conseil doit dominer la slide.          → BLOQUANT
 *   CHARTE          — couleurs, logo, taille du logo.            → BLOQUANT
 *   RÈGLE §6a       — un visuel se lit sans traduction.          → avertissement
 *   EMOJIS          — densité de marqueurs sur un post.          → avertissement
 *   ANTI-DOUBLON    — même indicateur ET même angle (03/09).     → avertissement
 *
 * POURQUOI 2 N'EST QU'UN AVERTISSEMENT
 * « pilotage » appartient au vocabulaire de marque (« Le Rythme de Pilotage »).
 * Un contrôle qui crie au loup à chaque slide finit ignoré — leçon du 21/09 :
 * « un contrôle qui n'a pas tourné n'est ni un succès ni 32 fausses erreurs ».
 * On signale, on ne bloque pas, et on dit toujours combien de fichiers ont été
 * réellement examinés.
 *
 * USAGE
 *   node scripts/controle-editorial.mjs <fichiers...>       HTML de carrousel, JSON de file
 *   node scripts/controle-editorial.mjs automation-agent/publications.json   tout le calendrier
 *   node scripts/controle-editorial.mjs --titre "..."       un slogan, avant génération
 *   node scripts/controle-editorial.mjs --sujet "..."       un sujet, avant de le caler
 *   node scripts/controle-editorial.mjs scripts/temoins/gabarit-casse.html   témoin : doit sortir 9 erreurs
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

/* ─────────── RÈGLE §1 — coupures de ligne au niveau de la phrase ───────────
 *
 * Trois défauts seulement, tous objectifs. Volontairement PAS de contrôle
 * « un seul mot sur la dernière ligne » : « Le projet / d'abord. / L'argent /
 * ensuite. » est un rythme voulu, validé le 22/09. Un contrôle qui condamne une
 * mise en page approuvée se fait désactiver, et emporte les autres avec lui.
 */
const MOTS_OUTILS = new Set([
  'le','la','les','un','une','des','du','de','d','au','aux','à','en','et','ou',
  'qui','que','qu','dans','sur','pour','par','avec','sans','son','sa','ses',
  'leur','leurs','ce','cet','cette','ne','se','il','elle','on','nos','vos','notre','votre',
]);

const nettoyer = s => s.replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ').trim();

function regle1(brut, fichier) {
  if (!/<br\s*\/?>/i.test(brut)) return;
  const segments = brut.split(/<br\s*\/?>/i).map(nettoyer).filter(Boolean);
  if (segments.length < 2) return;

  for (let i = 0; i < segments.length; i++) {
    const mots = segments[i].split(/\s+/);
    const dernier = mots[mots.length - 1].toLowerCase().replace(/[.,;:!?…'’]+$/g, '');

    // (a) un segment se termine par un mot outil — il a été coupé de son groupe
    if (i < segments.length - 1 && MOTS_OUTILS.has(dernier)) {
      err(fichier, '§1', `Coupure après « ${mots[mots.length - 1]} » : un mot de liaison reste seul en fin de ligne, séparé du groupe qu'il introduit.`, segments[i]);
    }
    // (b) un segment entier n'est qu'un mot outil
    if (mots.length === 1 && MOTS_OUTILS.has(dernier)) {
      err(fichier, '§1', `La ligne « ${segments[i]} » ne contient qu'un mot de liaison.`, null);
    }
    // (c) un nombre groupé coupé en deux — « 50 000 » sur deux lignes
    if (i < segments.length - 1 && /\d$/.test(segments[i]) && /^\d/.test(segments[i + 1])) {
      err(fichier, '§1', `Nombre coupé entre deux lignes : « ${segments[i].slice(-6)} » puis « ${segments[i + 1].slice(0, 6)} ».`, null);
    }
  }
}

/* ─────────── RÈGLES §2 et §4 — épaisseur, et le conseil doit dominer ───────────
 *
 * Deux lectures directes du CSS, sans jugement.
 *   §2 : un titre en dessous de 900, un encadré en dessous de 700, paraissent
 *        faibles même à la bonne taille.
 *   §4 : le conseil est la raison d'être de la slide. S'il est plus petit que
 *        le texte courant, il est illisible — défaut structurel du 17/08, où
 *        .callout p était à 21px contre 24px pour .item .text.
 */
function declarationsCss(html) {
  const css = [...html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/gi)].map(m => m[1]).join('\n');
  const regles = new Map();
  for (const m of css.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
    const corps = m[2];
    const taille = corps.match(/font-size:\s*(\d+(?:\.\d+)?)px/i);
    const graisse = corps.match(/font-weight:\s*(\d{3})/i);
    if (!taille && !graisse) continue;
    for (const sel of m[1].split(',').map(s => s.trim()).filter(Boolean)) {
      const p = regles.get(sel) || {};
      if (taille) p.taille = parseFloat(taille[1]);
      if (graisse) p.graisse = parseInt(graisse[1], 10);
      regles.set(sel, p);
    }
  }
  return regles;
}

const trouver = (regles, motif) => {
  for (const [sel, p] of regles) if (motif.test(sel)) return { sel, ...p };
  return null;
};

function regles2et4(html, fichier) {
  const r = declarationsCss(html);
  if (!r.size) return;

  // §2 — graisses
  for (const [motif, mini, quoi] of [
    [/\.main-title\b/, 900, 'titre de couverture'],
    [/\.cta-title\b/, 900, 'titre de CTA'],
    [/\.callout p\b/, 700, 'texte de l\'encadré conseil'],
    [/\.diag-callout\b/, 700, 'encadré de diagnostic'],
    [/\.callout-label\b/, 800, 'intitulé de l\'encadré'],
  ]) {
    const t = trouver(r, motif);
    if (t && t.graisse !== undefined && t.graisse < mini) {
      err(fichier, '§2', `${quoi} en font-weight ${t.graisse} — minimum ${mini}. Si le texte ne tient pas, réduire la taille, jamais la graisse.`, t.sel);
    }
  }

  // §4 — le conseil doit dominer le texte courant
  const conseil = trouver(r, /\.callout p\b/);
  const courant = trouver(r, /\.item .text\b/) || trouver(r, /\.index-desc\b/);
  if (conseil?.taille && courant?.taille && conseil.taille <= courant.taille) {
    err(fichier, '§4', `L'encadré conseil (${conseil.taille}px) n'est pas plus grand que le texte courant (${courant.taille}px). Le conseil est la raison d'être de la slide : il doit dominer.`, `${conseil.sel} vs ${courant.sel}`);
  }
}

/* ─────────── ANTI-DOUBLON — « même indicateur ET même angle » ───────────
 *
 * Règle du 03/09/2026 : un même indicateur peut revenir avec des chiffres neufs
 * si l'angle diffère. C'est la CONJONCTION qui bloque, pas le sujet voisin.
 *
 * Une machine sait mesurer la proximité d'indicateur. Elle ne sait pas juger de
 * l'angle — c'est une lecture, pas un calcul. Ce contrôle est donc un
 * AVERTISSEMENT par construction : il signale une proximité et donne la date de
 * l'autre publication ; la décision reste humaine. Le rendre bloquant
 * condamnerait des rapprochements légitimes et le ferait désactiver.
 *
 * Il aurait signalé la collision du 22/09 : mardi 13/10 « Le tableau de bord
 * vivant » et jeudi 15/10 « Un reporting qui aide à décider », à 48 heures.
 */
const VIDES = new Set([
  'avec','sans','pour','dans','plus','moins','tout','tous','toute','toutes','leur','leurs',
  'cette','cet','ces','celui','celle','ceux','autre','autres','meme','memes','entre','chaque',
  'quand','comme','mais','donc','alors','ainsi','encore','aussi','bien','faire','fait','etre',
  'avoir','peut','doit','sont','est','une','des','les','aux','par','sur','que','qui','quoi',
  'definir','post','court','long','carrousel','veille','economique','campagne','dediee','serie',
  'episode','banque','visuels','institutions','perfeco','nouvelle','caledonie','semaine','jeudi',
  'mardi','vendredi','annule','ferie','republication','facebook','linkedin','article',
  'niveau','angle','point','terme','chose','place','maniere','facon','moment','temp',
  'jour','annee','moi','fois','partie','ensemble','nombre','apres','avant','depuis',
]);

// FAMILLES D'INDICATEURS — c'est « le même indicateur » de la règle du 03/09.
// Le recouvrement littéral ne suffit pas : « Le tableau de bord vivant » et
// « Un reporting qui aide à décider » ne partagent AUCUN mot, et traitaient
// pourtant le même objet à 48 heures d'écart (collision relevée le 22/09).
const FAMILLES = {
  reporting:     ['tableau','bord','reporting','indicateur','kpi','donnee','mesure','chiffre','suivi'],
  decision:      ['decision','decider','arbitrage','trancher','arbitrer','comite','choix'],
  priorites:     ['priorite','cap','objectif','cascade','strategie','ambition'],
  coordination:  ['silo','transversal','service','equipe','coordination','collaborer','collaboration','ensemble'],
  argent:        ['cout','marge','tresorerie','depense','budget','financement','argent','investissement'],
  risques:       ['risque','anticiper','incident','panne','securite'],
  simplification:['processu','simplifier','simple','complexite','friction','lourdeur'],
  outils:        ['outil','numerique','digital','automatiser','logiciel','application'],
  competences:   ['competence','formation','recrutement','succession','depart','autonomie'],
};

function familles(texte) {
  const mots = new Set(normaliser(texte));
  const out = new Set();
  for (const [f, cles] of Object.entries(FAMILLES))
    if (cles.some(c => [...mots].some(m => m.startsWith(c) || c.startsWith(m))))
      out.add(f);
  return out;
}

const normaliser = t => (t || '')
  .toLowerCase()
  .normalize('NFD').replace(/[̀-ͯ]/g, '')
  .replace(/[^a-z0-9\s-]/g, ' ')
  .split(/\s+/)
  .map(m => m.replace(/s$/, ''))          // pluriel grossier, suffisant ici
  .filter(m => m.length >= 4 && !VIDES.has(m));

const semainesEntre = (a, b) =>
  Math.abs((new Date(a) - new Date(b)) / 604800000);

function proximite(a, b) {
  const A = new Set(normaliser(a)), B = new Set(normaliser(b));
  if (A.size < 2 || B.size < 2) return { score: 0, communs: [] };
  const communs = [...A].filter(m => B.has(m));
  return { score: communs.length, communs };
}

function antiDoublonRegistre(chemin) {
  const brut = readFileSync(chemin, 'utf8').replace(/^﻿/, '');
  let d; try { d = JSON.parse(brut); } catch { return; }
  if (!Array.isArray(d?.publications)) return;
  examines++;

  const vivantes = d.publications.filter(p =>
    p.statut !== 'annule' && p.format !== 'ferie' &&
    p.sujet && !/^(a|à) d[ée]finir/i.test(p.sujet));

  const aujourdhui = new Date().toISOString().slice(0, 10);
  const aVenir = vivantes.filter(p => p.date_nc >= aujourdhui);

  const trouvailles = [];
  for (const p of aVenir) {
    let pire = null;
    for (const q of vivantes) {
      if (q === p || q.date_nc > p.date_nc) continue;   // on ne compare qu'au passé du candidat
      const ecart = semainesEntre(p.date_nc, q.date_nc);
      if (ecart > 8) continue;                           // au-delà de 8 semaines, on se tait
      const { score, communs } = proximite(p.sujet, q.sujet);
      const fam = [...familles(p.sujet)].filter(f => familles(q.sujet).has(f));

      // Deux voies vers le signalement :
      //   — même famille d'indicateur à 4 semaines ou moins, même sans mot commun
      //   — 3 mots significatifs partagés (2 si la même quinzaine)
      const parFamille = fam.length > 0 && ecart <= 4;
      const parMots    = score >= (ecart <= 2 ? 2 : 3);
      if (!parFamille && !parMots) continue;

      const poids = fam.length * 10 + score - ecart;  // priorité à la famille, puis à la proximité
      if (!pire || poids > pire.poids) pire = { q, score, communs, ecart, fam, poids };
    }
    if (pire) {
      const j = Math.round(pire.ecart * 7);
      const cause = pire.fam.length
        ? `même famille d'indicateur (${pire.fam.join(', ')})`
        : `${pire.score} terme(s) partagé(s)`;
      trouvailles.push({ j, message:
        `${p.date_nc} « ${p.sujet.slice(0, 54)} » — ${cause} avec ${pire.q.date_nc} « ${pire.q.sujet.slice(0, 44)} », ${j} jour(s) d'écart. Vérifier que l'ANGLE diffère : c'est la conjonction qui bloque, pas le sujet voisin.`,
        extrait: pire.communs.length ? pire.communs.join(', ') : null });
    }
  }

  // Du plus serré au plus large : deux jours d'écart se traite avant vingt-huit.
  trouvailles.sort((a, b) => a.j - b.j);
  for (const t of trouvailles) avert(basename(chemin), 'anti-doublon', t.message, t.extrait);
  if (trouvailles.length) {
    console.log(`  ${GRIS}anti-doublon : ${aVenir.length} échéance(s) à venir comparées à ${vivantes.length} publication(s), ${trouvailles.length} proximité(s) signalée(s).${RAZ}`);
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

// La règle §1 porte aussi sur les encadrés : « tous les <br> des callouts
// doivent être recalés après un changement de taille » — leçon du 17/08.
function blocsCoupables(html) {
  const out = [];
  for (const re of [
    /<h1[^>]*>([\s\S]*?)<\/h1>/gi,
    /<h2[^>]*>([\s\S]*?)<\/h2>/gi,
    /<p[^>]*class="[^"]*subtitle[^"]*"[^>]*>([\s\S]*?)<\/p>/gi,
    /<div[^>]*class="[^"]*callout[^"]*"[^>]*>[\s\S]*?<p[^>]*>([\s\S]*?)<\/p>/gi,
    /<div[^>]*class="[^"]*diag-callout[^"]*"[^>]*>([\s\S]*?)<\/div>/gi,
    /<div[^>]*class="[^"]*index-desc[^"]*"[^>]*>([\s\S]*?)<\/div>/gi,
  ]) for (const m of html.matchAll(re)) out.push(m[1]);
  return out;
}

function traiterHtml(chemin) {
  const html = readFileSync(chemin, 'utf8');
  const nom = basename(chemin);
  examines++;
  for (const t of titresHtml(html)) { regle7(t, nom); regle6a(t, nom); }
  for (const b of blocsCoupables(html)) regle1(b, nom);
  regles2et4(html, nom);
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

if (args[0] === '--sujet') {
  // Tester un sujet candidat AVANT de le poser au calendrier.
  const sujet = args.slice(1).join(' ');
  const REG = 'automation-agent/publications.json';
  examines = 1;
  try {
    const d = JSON.parse(readFileSync(REG, 'utf8').replace(/^﻿/, ''));
    const vivantes = d.publications.filter(p => p.statut !== 'annule' && p.sujet && !/^(a|à) d[ée]finir/i.test(p.sujet));
    const proches = vivantes
      .map(q => ({ q, ...proximite(sujet, q.sujet) }))
      .filter(x => x.score >= 2)
      .sort((a, b) => b.score - a.score)
      .slice(0, 5);
    if (!proches.length) console.log(`
${VERT}Aucun sujet proche dans le registre.${RAZ}`);
    else for (const x of proches)
      avert('(sujet fourni)', 'anti-doublon',
        `${x.q.date_nc} « ${x.q.sujet.slice(0, 60)} » — ${x.score} terme(s) en commun.`, x.communs.join(', '));
  } catch (e) { console.error(`Registre illisible : ${e.message}`); process.exit(2); }
} else if (args[0] === '--titre') {
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
    else if (basename(a) === 'publications.json') antiDoublonRegistre(a);
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
