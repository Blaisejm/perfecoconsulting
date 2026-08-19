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
 */

import { query } from '@anthropic-ai/claude-agent-sdk';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

const [promptFile, outDir] = process.argv.slice(2);

if (!promptFile || !outDir) {
  console.error('Usage : node scripts/claude-agent-run.mjs <fichier-prompt> <dossier-sortie>');
  process.exit(2);
}
if (!process.env.ANTHROPIC_API_KEY) {
  console.error('::error::ANTHROPIC_API_KEY absent. Ajouter le secret dans Settings → Secrets and variables → Actions.');
  process.exit(2);
}

const prompt = readFileSync(resolve(promptFile), 'utf8');
mkdirSync(resolve(outDir), { recursive: true });

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
  console.error(`::error::La routine a échoué : ${error?.message ?? error}`);
  process.exit(1);
}

writeFileSync(resolve(outDir, 'transcript.json'), JSON.stringify(transcript, null, 2));

if (!resultMessage) {
  console.error("::error::Aucun message de type 'result' — la routine s'est arrêtée sans conclure.");
  process.exit(1);
}

// ⚠️ Les noms de champs du message `result` ne sont pas figés dans la doc publique.
// On écrit le message ENTIER dans l'artefact : le premier run nous donne sa forme
// exacte, et on durcira la lecture ensuite plutôt que de deviner maintenant.
writeFileSync(resolve(outDir, 'result.json'), JSON.stringify(resultMessage, null, 2));

const finalText = resultMessage.result ?? textOf(resultMessage) ?? '';
writeFileSync(resolve(outDir, 'sortie.md'), String(finalText));

const cost = resultMessage.total_cost_usd ?? resultMessage.cost_usd ?? null;
const turns = resultMessage.num_turns ?? null;
const ms = resultMessage.duration_ms ?? null;

console.log('\n──────── Bilan du run ────────');
console.log(`Coût     : ${cost === null ? 'non lu — voir result.json' : `$${Number(cost).toFixed(4)}`}`);
console.log(`Tours    : ${turns ?? 'non lu'}`);
console.log(`Durée    : ${ms === null ? 'non lue' : `${Math.round(ms / 1000)} s`}`);
console.log(`Sortie   : ${resolve(outDir, 'sortie.md')}`);

// Rendre le coût lisible par le workflow, pour l'afficher dans l'issue.
if (process.env.GITHUB_OUTPUT) {
  writeFileSync(process.env.GITHUB_OUTPUT, `cost=${cost ?? ''}\nturns=${turns ?? ''}\n`, { flag: 'a' });
}

if (resultMessage.is_error || resultMessage.subtype === 'error_max_turns') {
  console.error(`::error::Run terminé en erreur (subtype=${resultMessage.subtype ?? 'inconnu'}).`);
  process.exit(1);
}
