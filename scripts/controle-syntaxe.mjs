#!/usr/bin/env node
// ---------------------------------------------------------------------------
// PerfEco — Contrôle de syntaxe AU PUSH (garde-fou en amont)
//
// POURQUOI CE SCRIPT EXISTE (21/09/2026)
//
// Le 15/09, le commit 421f204 a remplacé les 18 lignes de logique d'un `if`
// par un bloc de commentaires dans publish-jeudi-post-court.yml. Le `if`
// n'était plus refermé. Le 17/09 à 11h00 NC le workflow est mort sur
// « line 12: syntax error: unexpected end of file » et LA PUBLICATION DU
// JEUDI A ÉTÉ PERDUE. Un `bash -n` d'une seconde l'aurait vu.
//
// La panne n'a été constatée que le lendemain midi par la routine de
// surveillance, et le filet quotidien (check-preparation-contenu.yml) tourne
// à 19h00 NC — huit heures APRÈS l'heure de publication. Les deux constatent
// les dégâts, aucun ne les empêche.
//
// Règle de Jean-Michel du 28/07/2026 : « toute fiabilisation du pipeline doit
// être vérifiée AVANT l'heure de publication, jamais après coup. » Ce script
// est cette règle mise en code, déclenchée à chaque push.
//
// CE QU'IL CONTRÔLE               | L'INCIDENT QU'IL AURAIT ÉVITÉ
//  1. bash -n des blocs `run:`    | jeudi 17/09 perdu (if non refermé)
//  2. JSON des files d'attente    | file illisible à l'heure de publication
//  3. BOM des .ps1 accentués      | trace-routine.ps1 illisible par PS 5.1 (12/09)
//  4. caractères de contrôle      | chemins Windows mangés, \a devenu BEL (12/09)
//  5. structure des workflows     | workflow que GitHub refuse de charger
//
// CE QU'IL NE CONTRÔLE PAS, et qu'il ne faut pas croire couvert : la
// justesse du contenu, la fraîcheur des files, les images, les tokens. Cela
// reste le travail de check-preparation-contenu.yml et des routines.
// ---------------------------------------------------------------------------

import { readFileSync, readdirSync, writeFileSync, mkdtempSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join, relative } from 'node:path';
import { tmpdir } from 'node:os';

const RACINE = process.cwd();
const erreurs = [];
const avertissements = [];
let controles = 0;

const erreur = (fichier, message) => erreurs.push({ fichier, message });
const avertir = (fichier, message) => avertissements.push({ fichier, message });
const relatif = (chemin) => relative(RACINE, chemin).split('\\').join('/');

// ── 1. bash -n sur chaque bloc `run:` des workflows ────────────────────────
//
// Les blocs sont des scalaires littéraux YAML (`run: |`). On les extrait par
// indentation plutôt qu'avec une bibliothèque YAML : aucune dépendance à
// installer, et le format des 9 workflows est homogène.
//
// Les expressions GitHub sont remplacées par un jeton avant le contrôle : en
// bash pur, l'ouverture d'une expression GitHub est une expansion de
// paramètre invalide et ferait échouer tous les blocs qui en contiennent.

function extraireBlocsRun(texte) {
  const lignes = texte.split(/\r?\n/);
  const blocs = [];
  for (let i = 0; i < lignes.length; i++) {
    const m = lignes[i].match(/^(\s*)(?:- )?run:\s*\|[-+]?\s*$/);
    if (!m) continue;
    const indentDeclaration = m[1].length;
    const corps = [];
    let j = i + 1;
    for (; j < lignes.length; j++) {
      const ligne = lignes[j];
      if (ligne.trim() === '') { corps.push(''); continue; }
      const indent = ligne.length - ligne.trimStart().length;
      if (indent <= indentDeclaration) break;
      corps.push(ligne);
    }
    const pleines = corps.filter((l) => l.trim() !== '');
    if (pleines.length === 0) { i = j - 1; continue; }
    // Désindentation sur la plus petite indentation réelle du bloc.
    const base = Math.min(...pleines.map((l) => l.length - l.trimStart().length));
    blocs.push({ ligne: i + 1, code: corps.map((l) => l.slice(base)).join('\n') });
    i = j - 1;
  }
  return blocs;
}

function controlerWorkflows() {
  const dossier = join(RACINE, '.github', 'workflows');
  if (!existsSync(dossier)) { avertir('.github/workflows', 'dossier absent'); return; }
  const temp = mkdtempSync(join(tmpdir(), 'perfeco-syntaxe-'));
  const fichiers = readdirSync(dossier).filter((f) => /\.ya?ml$/.test(f)).sort();

  for (const nom of fichiers) {
    const chemin = join(dossier, nom);
    const texte = readFileSync(chemin, 'utf8');
    const rel = relatif(chemin);

    // 5. structure minimale — un workflow sans `jobs:` n'est jamais chargé.
    if (!/^jobs:\s*$/m.test(texte)) erreur(rel, 'aucune section `jobs:` — GitHub refusera ce workflow');
    if (!/^on:/m.test(texte)) erreur(rel, 'aucun déclencheur `on:`');
    if (/^[ ]*\t/m.test(texte)) erreur(rel, 'TABULATION en début de ligne — YAML interdit la tabulation pour l\'indentation');

    // 1. bash -n
    const blocs = extraireBlocsRun(texte);
    // Un workflow peut n'avoir que des `run:` d'une seule ligne (`run: node …`) :
    // il n'y a alors rien à passer à `bash -n`, ce n'est pas une anomalie.
    if (blocs.length === 0 && !/^\s*(?:- )?run:/m.test(texte)) {
      avertir(rel, 'aucune étape `run:` détectée — vérifier que le format n\'a pas changé');
    }
    for (const bloc of blocs) {
      controles++;
      const code = bloc.code.replace(/\$\{\{[^}]*\}\}/g, 'GHEXPR');
      const tmpFichier = join(temp, `${nom}-${bloc.ligne}.sh`);
      writeFileSync(tmpFichier, code, 'utf8');
      try {
        execFileSync('bash', ['-n', tmpFichier], { stdio: 'pipe' });
      } catch (e) {
        const detail = ((e.stderr && e.stderr.toString()) || e.message).trim()
          .split('\n').map((l) => l.split(tmpFichier).join(`bloc run: ligne ${bloc.ligne}`)).join(' | ');
        erreur(rel, `bloc \`run:\` commençant ligne ${bloc.ligne} — erreur de syntaxe bash : ${detail}`);
      }
    }
  }
}

// ── 2. JSON des files d'attente et du registre ─────────────────────────────
//
// Une file d'attente illisible ne se découvre aujourd'hui qu'à l'heure de
// publication, quand `jq` échoue dans le runner.

function controlerJson() {
  for (const dossier of ['automation-queue', 'automation-agent']) {
    const chemin = join(RACINE, dossier);
    if (!existsSync(chemin)) continue;
    for (const nom of readdirSync(chemin).filter((f) => f.endsWith('.json')).sort()) {
      controles++;
      const rel = `${dossier}/${nom}`;
      const brut = readFileSync(join(chemin, nom));
      if (brut[0] === 0xef && brut[1] === 0xbb && brut[2] === 0xbf) {
        erreur(rel, 'BOM UTF-8 en tête — `jq` et `JSON.parse` le refusent');
        continue;
      }
      try { JSON.parse(brut.toString('utf8')); }
      catch (e) { erreur(rel, `JSON invalide : ${e.message}`); }
    }
  }
}

// ── Parcours commun des fichiers du dépôt ──────────────────────────────────

function parcourir(dossier, visiteur) {
  for (const entree of readdirSync(dossier, { withFileTypes: true })) {
    if (['node_modules', '.git', 'dist', '.astro'].includes(entree.name)) continue;
    const chemin = join(dossier, entree.name);
    if (entree.isDirectory()) parcourir(chemin, visiteur);
    else visiteur(chemin, entree.name);
  }
}

// ── 3. BOM des .ps1 accentués ──────────────────────────────────────────────
//
// PowerShell 5.1 lit un .ps1 sans BOM en ANSI : les accents deviennent du
// mojibake et le parseur casse. Le 12/09, trace-routine.ps1 réécrit sans BOM
// est devenu illisible ; le 14/09, une classe de caractères accentués a cassé
// un autre .ps1 AU PARSING, sur un message trompeur de parenthèse manquante.

function controlerPs1() {
  parcourir(RACINE, (chemin, nom) => {
    if (!nom.endsWith('.ps1')) return;
    controles++;
    const brut = readFileSync(chemin);
    const aBom = brut[0] === 0xef && brut[1] === 0xbb && brut[2] === 0xbf;
    const accentue = /[^\x00-\x7F]/.test(brut.toString('utf8'));
    if (accentue && !aBom) {
      erreur(relatif(chemin), 'caractères non-ASCII SANS BOM UTF-8 — PowerShell 5.1 le lira en ANSI et le parseur cassera (incident du 12/09/2026)');
    }
  });
}

// ── 4. Caractères de contrôle ──────────────────────────────────────────────
//
// Le 12/09, un échappement bash a transformé deux séquences d'un chemin
// Windows en BEL et tabulation verticale dans 8 fiches de routine. Invisible
// à l'écran, fatal à l'exécution.

function controlerCaracteresDeControle() {
  const extensions = /\.(ps1|json|ya?ml|mjs|cjs|js|md)$/;
  const interdits = [[0x07, 'BEL'], [0x0b, 'TABULATION VERTICALE'], [0x0c, 'SAUT DE PAGE'], [0x00, 'NUL']];
  parcourir(RACINE, (chemin, nom) => {
    if (!extensions.test(nom)) return;
    controles++;
    const brut = readFileSync(chemin);
    for (const [code, libelle] of interdits) {
      const index = brut.indexOf(code);
      if (index === -1) continue;
      const ligne = brut.slice(0, index).toString('utf8').split('\n').length;
      erreur(relatif(chemin),
        `caractère de contrôle ${libelle} à la ligne ${ligne} — trace d'un chemin Windows mangé par un échappement (incident du 12/09/2026)`);
    }
  });
}

// ── Exécution ──────────────────────────────────────────────────────────────

console.log('════════ Contrôle de syntaxe PerfEco (garde-fou au push) ════════\n');
controlerWorkflows();
controlerJson();
controlerPs1();
controlerCaracteresDeControle();

console.log(`${controles} contrôle(s) exécuté(s).\n`);

for (const a of avertissements) console.log(`##[warning]${a.fichier} — ${a.message}`);
if (avertissements.length) console.log('');

if (erreurs.length === 0) {
  console.log('✅ Aucune anomalie de syntaxe. Le pipeline est chargeable en l\'état.');
  process.exit(0);
}

console.log('════════ Bilan ════════');
for (const e of erreurs) console.log(`##[error]${e.fichier} — ${e.message}`);
console.log(`\n##[error]${erreurs.length} anomalie(s) de syntaxe. Ce contrôle tourne AVANT l'heure de publication : corriger maintenant coûte une minute, le découvrir à 11h00 coûte une publication.`);
process.exit(1);
