/**
 * Exécute une routine éditoriale PerfEco via le Claude Agent SDK, en headless.
 *
 * POURQUOI CE SCRIPT EXISTE (19/08/2026)
 * --------------------------------------
 * Les routines de production tournent aujourd'hui dans Cowork, avec un jeton OAuth
 * interactif. Quand ce jeton expire, la session meurt au PREMIER appel d'outil et ne
 * peut même pas alerter — cause racine établie le 18/08/2026 (voir
 * .github/workflows/check-preparation-contenu.yml).
 *
 * Une clé API (ANTHROPIC_API_KEY) n'a pas ce mode de défaillance. Ce script est le
 * premier essai : faire tourner une routine dans GitHub Actions, en parallèle de
 * Cowork, sans rien publier, pour comparer les sorties et mesurer le coût réel.
 *
 * Usage : node scripts/claude-agent-run.mjs <fichier-prompt> <dossier-sortie>
 *
 * Le script écrit TOUJOURS `issue.md` et `issue-title.txt` dans le dossier de sortie,
 * y compris quand il échoue — c'est le workflow qui les publie. Composer le corps de
 * l'issue ici plutôt qu'en bash évite les pièges de quoting qui ont fait échouer le
 * run #1 (19/08/2026).
 */

import { query } from '@anthropic-ai/claude-agent-sdk';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

const [promptFile, outDir] = process.argv.slice(2);

if (!promptFile || !outDir) {
  console.error('Usage : node scripts/claude-agent-run.mjs <fichier-prompt> <dossier-sortie>');
  process.exit(2);
}
mkdirSync(resolve(outDir), { recursive: true });

const runNumber = process.env.GITHUB_RUN_NUMBER ?? '0';
const runUrl =
  process.env.GITHUB_SERVER_URL && process.env.GITHUB_REPOSITORY && process.env.GITHUB_RUN_ID
    ? `${process.env.GITHUB_SERVER_URL}/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_ID}`
    : '(hors GitHub Actions)';

/** Compose l'issue et l'écrit sur disque. Appelé sur TOUS les chemins de sortie. */
function ecrireIssue({ etat, cout, tours, corps, erreur }) {
  const lignes = [
    '> **Essai en parallèle — rien n\'a été publié.**',
    '> La routine Cowork `vendredi-veilleeco-creation` reste la production.',
    '> Cette issue sert à comparer les deux sorties de la même semaine.',
    '',
    '| | |',
    '|---|---|',
    `| État | ${etat} |`,
    `| Coût du run | ${cout === null || cout === undefined ? 'non lu — voir result.json dans l\'artefact' : '$' + Number(cout).toFixed(4)} |`,
    `| Tours | ${tours ?? 'non lu'} |`,
    `| Trace complète | artefact \`essai-veille-eco-${runNumber}\` |`,
    `| Run | ${runUrl} |`,
    '',
    '---',
    '',
  ];

  if (erreur) {
    lignes.push('## La routine a échoué', '', '```', String(erreur).slice(0, 3000), '```', '');
  }
  lignes.push(corps && corps.trim() ? corps : '_Aucune sortie produite._');

  writeFileSync(resolve(outDir, 'issue.md'), lignes.join('\n'));
  writeFileSync(
    resolve(outDir, 'issue-title.txt'),
    `Essai cle API - veille eco - run ${runNumber} (${etat})`,
  );
}

if (!process.env.ANTHROPIC_API_KEY) {
  const message =
    'ANTHROPIC_API_KEY absent. Ajouter le secret dans Settings > Secrets and variables > Actions.';
  console.error(`::error::${message}`);
  ecrireIssue({ etat: 'échec', cout: null, tours: null, corps: '', erreur: message });
  process.exit(2);
}

const prompt = readFileSync(resolve(promptFile), 'utf8');
const transcript = [];
let resultMessage = null;

/** Extrait le texte lisible d'un message, quelle que soit la forme du contenu. */
function textOf(message) {
  const content = message?.message?.content ?? message?.content;
  if (typeof content === 'string') return content;
  if (!Array.isArray(content)) return '';
  return content
    .filter((block) => block?.type === 'text' && typeof block.text === 'string')
    .map((block) => block.text)
    .join('\n');
}

/** Nomme l'outil appelé, pour que le log dise ce que l'agent fait réellement. */
function toolNamesOf(message) {
  const content = message?.message?.content ?? message?.content;
  if (!Array.isArray(content)) return [];
  return content.filter((block) => block?.type === 'tool_use').map((block) => block.name);
}

console.log(`▶ Routine : ${promptFile}`);
console.log(`▶ Modèle  : claude-opus-5\n`);

try {
  for await (const message of query({
    prompt,
    options: {
      model: 'claude-opus-5',
      cwd: process.cwd(),
      maxTurns: 60,

      // Runner GitHub jetable, sans humain pour approuver : on autorise les outils.
      // Les règles de refus ci-dessous s'appliquent MALGRÉ ce mode (elles sont
      // évaluées avant lui) — c'est ce qui garantit qu'un shadow run ne publie rien.
      permissionMode: 'bypassPermissions',
      disallowedTools: [
        'Bash(git push*)',   // ne jamais pousser depuis un shadow run
        'Bash(gh *)',        // ni ouvrir/commenter quoi que ce soit via gh
        'Bash(curl *)',      // ni appeler un webhook de publication
        'Bash(rm *)',
      ],

      // Aucun réglage hérité du disque : le run doit être reproductible à
      // l'identique d'une exécution à l'autre.
      settingSources: [],
    },
  })) {
    transcript.push(message);

    if (message.type === 'assistant') {
      const text = textOf(message);
      if (text.trim()) console.log(`\n${text}\n`);
      for (const tool of toolNamesOf(message)) console.log(`  ↳ ${tool}`);
    } else if (message.type === 'result') {
      resultMessage = message;
    }
  }
} catch (error) {
  writeFileSync(resolve(outDir, 'transcript.json'), JSON.stringify(transcript, null, 2));
  const message = error?.stack ?? error?.message ?? String(error);
  console.error(`::error::La routine a échoué : ${error?.message ?? error}`);
  ecrireIssue({ etat: 'échec', cout: null, tours: null, corps: '', erreur: message });
  process.exit(1);
}

writeFileSync(resolve(outDir, 'transcript.json'), JSON.stringify(transcript, null, 2));

if (!resultMessage) {
  const message = "Aucun message de type 'result' — la routine s'est arrêtée sans conclure.";
  console.error(`::error::${message}`);
  ecrireIssue({ etat: 'échec', cout: null, tours: null, corps: '', erreur: message });
  process.exit(1);
}

// ⚠️ Les noms de champs du message `result` ne sont pas figés dans la doc publique.
// On écrit le message ENTIER dans l'artefact : le premier run nous donne sa forme
// exacte, et on durcira la lecture ensuite plutôt que de deviner maintenant.
writeFileSync(resolve(outDir, 'result.json'), JSON.stringify(resultMessage, null, 2));

const finalText = String(resultMessage.result ?? textOf(resultMessage) ?? '');
writeFileSync(resolve(outDir, 'sortie.md'), finalText);

const cost = resultMessage.total_cost_usd ?? resultMessage.cost_usd ?? null;
const turns = resultMessage.num_turns ?? null;
const ms = resultMessage.duration_ms ?? null;
const enErreur = Boolean(resultMessage.is_error) || resultMessage.subtype === 'error_max_turns';

console.log('\n──────── Bilan du run ────────');
console.log(`Coût     : ${cost === null ? 'non lu — voir result.json' : `$${Number(cost).toFixed(4)}`}`);
console.log(`Tours    : ${turns ?? 'non lu'}`);
console.log(`Durée    : ${ms === null ? 'non lue' : `${Math.round(ms / 1000)} s`}`);
console.log(`Champs du message result : ${Object.keys(resultMessage).join(', ')}`);

ecrireIssue({
  etat: enErreur ? 'terminé en erreur' : 'succès',
  cout: cost,
  tours: turns,
  corps: finalText,
  erreur: null,
});

// Rendre le coût lisible par le workflow.
if (process.env.GITHUB_OUTPUT) {
  writeFileSync(process.env.GITHUB_OUTPUT, `cost=${cost ?? ''}\nturns=${turns ?? ''}\n`, { flag: 'a' });
}

if (enErreur) {
  console.error(`::error::Run terminé en erreur (subtype=${resultMessage.subtype ?? 'inconnu'}).`);
  process.exit(1);
}
