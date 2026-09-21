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
//  6. parsing réel des .ps1       | routine morte au lancement sur une erreur
//                                 | de syntaxe — l'équivalent PowerShell du
//                                 | `if` non refermé du 17/09
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

// `bash` n'est pas dans le PATH d'une console PowerShell. Sans cette détection,
// chaque bloc `run:` échouait sur « spawnSync bash ENOENT » et le rapport
// affichait 32 ERREURS DE SYNTAXE pour des fichiers parfaitement sains.
// Un garde-fou qui crie au loup 32 fois faute d'un outil finit par être ignoré,
// et c'est le jour où il a raison que personne ne le lit — même mode de
// défaillance que les faux positifs du filet quotidien des 31/08 et 01-02/09.
// Un outil manquant se signale UNE fois, et ne se confond jamais avec un défaut
// du code contrôlé.
function bashDisponible() {
  try { execFileSync('bash', ['-c', 'exit 0'], { stdio: 'pipe' }); return true; }
  catch { return false; }
}

function controlerWorkflows() {
  const dossier = join(RACINE, '.github', 'workflows');
  if (!existsSync(dossier)) { avertir('.github/workflows', 'dossier absent'); return; }
  const temp = mkdtempSync(join(tmpdir(), 'perfeco-syntaxe-'));
  const fichiers = readdirSync(dossier).filter((f) => /\.ya?ml$/.test(f)).sort();

  const avecBash = bashDisponible();
  if (!avecBash) {
    const message = '`bash` introuvable — la syntaxe des blocs `run:` n\'a PAS été contrôlée';
    if (process.env.GITHUB_ACTIONS || process.env.CI) {
      erreur('scripts/controle-syntaxe.mjs', `${message}, alors que ce contrôle tourne en intégration continue : un vert serait mensonger`);
    } else {
      avertir('scripts/controle-syntaxe.mjs', `${message} (console PowerShell — relancer depuis Git Bash, ou laisser le push s'en charger)`);
    }
  }

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
      if (!avecBash) continue;
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

let ps1Vus = 0;

function controlerPs1() {
  parcourir(RACINE, (chemin, nom) => {
    if (!nom.endsWith('.ps1')) return;
    controles++;
    ps1Vus++;
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

// ── 6. Parsing réel des .ps1 ───────────────────────────────────────────────
//
// Le contrôle 3 ne regarde que l'ENCODAGE : un .ps1 parfaitement encodé mais
// syntaxiquement cassé passait au vert. C'est exactement le trou qu'avait le
// pipeline côté bash avant le 17/09, quand un `if` non refermé a coûté une
// publication. Une routine qui meurt au lancement sur une parenthèse manquante
// ne publie rien et, pire, ne peut pas signaler sa propre panne.
//
// On passe donc chaque .ps1 au vrai parseur PowerShell, celui qui servira à
// l'exécution. Deux précautions qui comptent :
//
//   - LA SORTIE PASSE PAR UN FICHIER UTF-8, jamais par stdout. Sur un Windows
//     français, la sortie console de PowerShell est en page OEM : les messages
//     d'erreur accentués reviendraient en mojibake et deviendraient illisibles
//     au moment precis ou on en a besoin.
//
//   - UN CONTRÔLE QUI N'A PAS TOURNÉ N'EST JAMAIS UN SUCCÈS. Le script compte
//     les fichiers qu'il a réellement examinés, et on recoupe ce nombre avec
//     celui du contrôle 3. Tout écart est une erreur : sans cela, un parseur
//     qui plante à mi-chemin rendrait « 0 anomalie », soit un vert mensonger —
//     la famille d'incidents la plus coûteuse de ce projet.
//
// LIMITE À CONNAÎTRE : sur le runner ubuntu, l'interpréteur est pwsh 7, dont
// le parseur accepte quelques constructions que PowerShell 5.1 — celui des
// routines locales — refuse (`??`, `?.`, ternaire). Le contrôle reste donc
// plus permissif que la réalité d'exécution, jamais plus strict.

const SCRIPT_PARSE_PS1 = [
  'param([string]$Racine, [string]$Sortie)',
  '$ErrorActionPreference = "Stop"',
  '$motifExclusion = "[\\\\/](node_modules|\\.git|dist|\\.astro)[\\\\/]"',
  '$lignes = New-Object System.Collections.Generic.List[string]',
  '$n = 0',
  '$fichiers = Get-ChildItem -LiteralPath $Racine -Recurse -File -Filter *.ps1 -ErrorAction SilentlyContinue |',
  '    Where-Object { $_.FullName -notmatch $motifExclusion }',
  'foreach ($f in $fichiers) {',
  '    $n++',
  '    $erreurs = $null',
  '    $null = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$erreurs)',
  '    if ($erreurs) {',
  '        $rel = $f.FullName.Substring($Racine.Length).TrimStart("\\", "/").Replace("\\", "/")',
  '        foreach ($e in $erreurs) {',
  '            $msg = ($e.Message -replace "[\\r\\n]+", " ")',
  '            $lignes.Add("ERREUR|" + $rel + "|" + $e.Extent.StartLineNumber + "|" + $msg)',
  '        }',
  '    }',
  '}',
  '$lignes.Add("FICHIERS|" + $n)',
  '$lignes.Add("VERSION|" + $PSVersionTable.PSVersion.ToString())',
  '[System.IO.File]::WriteAllLines($Sortie, $lignes, (New-Object System.Text.UTF8Encoding($false)))',
].join('\n');

function trouverPowerShell() {
  for (const candidat of ['pwsh', 'powershell']) {
    try {
      execFileSync(candidat, ['-NoProfile', '-Command', 'exit 0'], { stdio: 'pipe' });
      return candidat;
    } catch { /* interpréteur absent : on essaie le suivant */ }
  }
  return null;
}

function controlerParsingPowerShell() {
  if (ps1Vus === 0) return;   // aucun .ps1 dans le dépôt : rien à parser

  const interpreteur = trouverPowerShell();
  if (!interpreteur) {
    const message = 'aucun interpréteur PowerShell (pwsh ni powershell) — le parsing des .ps1 n\'a PAS été contrôlé';
    if (process.env.GITHUB_ACTIONS || process.env.CI) {
      erreur('scripts/controle-syntaxe.mjs', `${message}, alors que ce contrôle tourne en intégration continue : un vert serait mensonger`);
    } else {
      avertir('scripts/controle-syntaxe.mjs', `${message} (exécution locale — le contrôle sera fait au push)`);
    }
    return;
  }

  const temp = mkdtempSync(join(tmpdir(), 'perfeco-ps1-'));
  const script = join(temp, 'parse-ps1.ps1');
  const sortie = join(temp, 'resultat.txt');
  // Script volontairement en ASCII pur : il n'a alors pas besoin de BOM, et ne
  // peut pas tomber lui-même dans le piège d'encodage qu'il sert à détecter.
  writeFileSync(script, SCRIPT_PARSE_PS1, 'ascii');

  try {
    execFileSync(interpreteur, ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script,
                                '-Racine', RACINE, '-Sortie', sortie], { stdio: 'pipe' });
  } catch (e) {
    const detail = ((e.stderr && e.stderr.toString()) || e.message).trim().split('\n').join(' | ');
    erreur('scripts/controle-syntaxe.mjs', `le parsing PowerShell n'a pas pu s'exécuter (${interpreteur}) : ${detail}`);
    return;
  }

  if (!existsSync(sortie)) {
    erreur('scripts/controle-syntaxe.mjs', `le parsing PowerShell n'a produit aucun résultat (${interpreteur}) — contrôle réputé NON FAIT`);
    return;
  }

  const lignes = readFileSync(sortie, 'utf8').split(/\r?\n/).filter((l) => l.trim() !== '');
  const ligneCompte = lignes.find((l) => l.startsWith('FICHIERS|'));
  const ligneVersion = lignes.find((l) => l.startsWith('VERSION|'));

  if (!ligneCompte) {
    erreur('scripts/controle-syntaxe.mjs', 'le parsing PowerShell s\'est interrompu avant la fin — contrôle réputé NON FAIT');
    return;
  }

  const parses = Number(ligneCompte.split('|')[1]);
  controles += parses;

  // Recoupement : le parseur doit avoir vu exactement les mêmes fichiers que le
  // contrôle 3. Un écart signifie qu'une partie du dépôt est passée au travers.
  if (parses !== ps1Vus) {
    erreur('scripts/controle-syntaxe.mjs',
      `le parsing PowerShell a examiné ${parses} fichier(s) .ps1 alors que le dépôt en compte ${ps1Vus} — des fichiers n'ont pas été contrôlés`);
  }

  for (const ligne of lignes) {
    if (!ligne.startsWith('ERREUR|')) continue;
    const [, fichier, numero, ...reste] = ligne.split('|');
    erreur(fichier, `erreur de syntaxe PowerShell ligne ${numero} : ${reste.join('|')}`);
  }

  const version = ligneVersion ? ligneVersion.split('|')[1] : 'inconnue';
  console.log(`Parsing PowerShell : ${parses} fichier(s) .ps1 via ${interpreteur} ${version}.`);
  if (/^[67-9]|^\d{2}/.test(version)) {
    console.log('  (PowerShell 7 est un peu plus permissif que le 5.1 des routines locales : ce contrôle ne peut pas être plus strict que l\'exécution réelle.)');
  }
}

// ── Exécution ──────────────────────────────────────────────────────────────

console.log('════════ Contrôle de syntaxe PerfEco (garde-fou au push) ════════\n');
controlerWorkflows();
controlerJson();
controlerPs1();
controlerCaracteresDeControle();
controlerParsingPowerShell();

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
