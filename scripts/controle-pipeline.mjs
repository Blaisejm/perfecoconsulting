/**
 * Contrôle quotidien du pipeline de publication PerfEco.
 *
 * POURQUOI CE SCRIPT (21/08/2026)
 * -------------------------------
 * Il tourne dans GitHub Actions, donc SANS dépendre du jeton OAuth de Cowork. C'est la
 * seule position d'où l'on peut constater qu'une routine Cowork n'a rien produit : une
 * routine morte ne peut pas alerter, puisque alerter est aussi un appel d'outil.
 *
 * Il remplace le corps bash de check-preparation-contenu.yml, qui ne vérifiait que la
 * présence de `date_prevue`. Les quatre pannes des 19 et 21/08/2026 lui échappaient :
 *
 *   1. Schéma périmé  — une tâche écrite avant la refonte Make du 12/08 produisait des
 *      blocs linkedin_company/facebook ; le workflow lit .social_post.message et aurait
 *      publié un message vide, avec un run en succès apparent.  → contrôle SCHÉMA
 *   2. Bascule sans effet — perfeco-bascule-mardi-w34 s'est exécutée, marquée terminée,
 *      sans rien écrire ; mardi.json est resté sur la semaine précédente. → contrôle STAGING
 *   3. Image injoignable — jamais vérifiée avant l'heure de publication. → contrôle IMAGE
 *   4. Dérive de date — une session étalée sur deux jours a calculé ses échéances depuis
 *      une date périmée. → toutes les dates calculées sont IMPRIMÉES, pas supposées.
 *
 * Principe directeur : ne jamais conclure « c'est prêt » depuis un statut ou un nom de
 * fichier. Toujours lire le contenu réel et le comparer à l'échéance réelle.
 *
 * Usage : node scripts/controle-pipeline.mjs [--json]
 * Sortie : 0 si tout va bien, 1 si au moins une anomalie bloquante.
 */

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { basename, dirname } from 'node:path';
import { execSync } from 'node:child_process';

const CALENDRIER = 'automation-agent/calendrier.json';
const JOURS = { dimanche: 0, lundi: 1, mardi: 2, mercredi: 3, jeudi: 4, vendredi: 5, samedi: 6 };

const anomalies = [];
const avertissements = [];
const journal = [];

function bloquant(msg) { anomalies.push(msg); }
function alerter(msg) { avertissements.push(msg); }
function dire(msg) { journal.push(msg); console.log(msg); }

/** Date du jour dans le fuseau donné, en AAAA-MM-JJ. Jamais supposée, toujours calculée. */
function aujourdhui(fuseau) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: fuseau, year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(new Date());
}

/** Jour de la semaine (0-6) d'une date AAAA-MM-JJ, sans dérive de fuseau. */
function jourSemaine(iso) {
  return new Date(`${iso}T12:00:00Z`).getUTCDay();
}

/** Prochaine occurrence du jour voulu, à partir d'aujourd'hui inclus. */
function prochaineOccurrence(isoDepuis, jourVoulu) {
  const base = new Date(`${isoDepuis}T12:00:00Z`);
  for (let i = 0; i < 14; i++) {
    const d = new Date(base.getTime() + i * 86400000);
    if (d.getUTCDay() === jourVoulu) return d.toISOString().slice(0, 10);
  }
  throw new Error('jour introuvable');
}

function ecartJours(isoA, isoB) {
  return Math.round((new Date(`${isoB}T12:00:00Z`) - new Date(`${isoA}T12:00:00Z`)) / 86400000);
}

/** Lit un chemin pointé (« social_post.message ») dans un objet. */
function lireChamp(objet, chemin) {
  return chemin.split('.').reduce((o, k) => (o == null ? undefined : o[k]), objet);
}

function chargerJson(chemin) {
  try {
    return { ok: true, data: JSON.parse(readFileSync(chemin, 'utf8')) };
  } catch (e) {
    return { ok: false, erreur: e.message };
  }
}

/**
 * Dernier traitement AYANT RÉELLEMENT ÉCRIT dans un fichier, avec date et heure.
 *
 * Demandé par Jean-Michel le 21/08/2026, et c'est la bonne question : `lastRunAt`
 * d'une tâche planifiée prouve un DÉCLENCHEMENT, jamais un RÉSULTAT. Démonstration
 * du jour même — `perfeco-veille-eco-21082026` affiche lastRunAt = 20/08 09:00:40
 * et s'est auto-désactivée comme une tâche accomplie ; git montre qu'elle n'a rien
 * écrit, le chargement ayant été fait la veille à 21h12 par la relance quotidienne.
 *
 * Un commit git est une preuve d'effet : il n'existe que si quelque chose a écrit.
 */
function dernierTraitement(chemin) {
  try {
    const out = execSync(
      `git log -1 --date=format:"%Y-%m-%d %H:%M" --format="%ad|%h|%s" -- "${chemin}"`,
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] },
    ).trim();
    if (!out) return null;
    const [date, sha, sujet] = out.split('|');
    return { date, sha, sujet };
  } catch {
    return null;
  }
}

/** Une URL d'image est-elle réellement servie ? Un 404 la veille = publication cassée. */
async function imageJoignable(url) {
  try {
    const r = await fetch(url, { method: 'GET', redirect: 'follow' });
    return { ok: r.ok, code: r.status };
  } catch (e) {
    return { ok: false, code: `injoignable (${e.message})` };
  }
}

// ─────────────────────────────────────────────────────────────────────────────

const cal = chargerJson(CALENDRIER);
if (!cal.ok) {
  console.error(`::error::${CALENDRIER} illisible : ${cal.erreur}`);
  process.exit(1);
}
const calendrier = cal.data;
const fuseau = calendrier.fuseau ?? 'Pacific/Noumea';
const today = aujourdhui(fuseau);
const seuil = calendrier.regle_j7?.seuil_alerte_jours ?? 7;

dire('════════ Contrôle quotidien du pipeline PerfEco ════════');
dire(`Date du jour (${fuseau}) : ${today}`);
dire(`Seuil d'alerte J-${seuil} — au-delà, une échéance non préparée devient bloquante.`);
dire('');

// Le registre central est chargé ICI, avant la boucle des formats : c'est lui qui
// donne la date de la prochaine diffusion, y compris lors d'un décalage pour férié.
// Il est revérifié en détail plus bas (section « Registre central des publications »).
const REGISTRE = 'automation-agent/publications.json';
const regf = chargerJson(REGISTRE);
const regPub = regf.ok ? regf.data : null;

const echeances = [];

for (const [cle, f] of Object.entries(calendrier.formats)) {
  dire(`──── ${cle.toUpperCase()} — ${f.libelle} ────`);

  // ── QUELLE EST LA PROCHAINE DIFFUSION ? ──────────────────────────────────
  // LE REGISTRE FAIT FOI, le jour de la semaine n'est qu'un repli.
  //
  // Corrigé le 21/08/2026. Ce contrôle déduisait la prochaine échéance du seul
  // jour de la semaine (« prochain mardi »). La semaine du 24/09/2026 publie le
  // lundi 21/09 et le mercredi 23/09 (jeudi férié en NC, décision de Jean-Michel) :
  // le contrôle aurait attendu le mardi 22/09, constaté que la file porte le 21/09,
  // et déclaré une anomalie BLOQUANTE sur un pipeline parfaitement correct.
  // Le filet indépendant aurait crié au loup précisément la semaine sensible — et
  // c'est ainsi qu'un filet cesse d'être lu.
  const registrePrevu = (regPub?.publications ?? [])
    .filter((p) => p.format === cle && p.date_nc >= today && p.statut !== 'annule')
    .map((p) => p.date_nc)
    .sort()[0];

  const parJour = prochaineOccurrence(today, JOURS[f.jour]);
  const prochaine = registrePrevu ?? parJour;
  const restant = ecartJours(today, prochaine);

  if (registrePrevu && registrePrevu !== parJour) {
    dire(`  Prochaine diffusion : ${prochaine} (dans ${restant} j, ${f.heure_nc} NC) — ⚠️ DÉCALAGE EXCEPTIONNEL, le jour habituel serait le ${parJour}. Source : automation-agent/publications.json.`);
  } else {
    dire(`  Prochaine diffusion : ${prochaine} (dans ${restant} j, ${f.heure_nc} NC)`);
    if (!registrePrevu) {
      alerter(`${cle} — aucune échéance à venir dans le registre : la date est déduite du jour de la semaine (${parJour}), ce qui ne tient pas compte des décalages pour férié. Ajouter l'entrée dans publications.json.`);
    }
  }

  // ── Fichier de file d'attente ────────────────────────────────────────────
  if (!existsSync(f.file)) {
    bloquant(`${cle} — ${f.file} introuvable. La routine ${f.routine} ne l'a jamais écrit.`);
    dire('');
    continue;
  }
  const q = chargerJson(f.file);
  if (!q.ok) {
    bloquant(`${cle} — ${f.file} n'est pas un JSON valide : ${q.erreur}`);
    dire('');
    continue;
  }
  const datePrevue = q.data.date_prevue;
  dire(`  ${basename(f.file)} : date_prevue=${datePrevue ?? 'ABSENT'} semaine=${q.data.semaine ?? 'ABSENT'}`);

  // Traçabilité : qui a écrit en dernier, quand. Preuve d'effet, pas de déclenchement.
  const dt = dernierTraitement(f.file);
  dire(dt
    ? `  dernier traitement effectif : ${dt.date} — ${dt.sha} « ${dt.sujet.slice(0, 70)} »`
    : `  dernier traitement effectif : inconnu (aucun commit trouvé)`);

  // ── SCHÉMA : le contrôle qui manquait le 19/08 (9e échec) ────────────────
  // Un fichier peut porter la bonne date et rester invalide : c'est exactement ce
  // qu'aurait fait la tâche du 21/08 avec son schéma d'avant la refonte du 12/08.
  for (const champ of f.champs_requis) {
    const v = lireChamp(q.data, champ);
    if (v === undefined || v === null || (typeof v === 'string' && v.trim() === '')) {
      bloquant(`${cle} — champ « ${champ} » absent ou vide dans ${f.file}. C'est précisément ce que lit ${f.workflow} : la publication partirait vide, avec un run en succès apparent.`);
    }
  }

  // ── IMAGE : jamais vérifiée avant l'heure de publication jusqu'ici ────────
  const img = lireChamp(q.data, 'social_post.image_url');
  if (typeof img === 'string' && img.startsWith('http')) {
    const r = await imageJoignable(img);
    dire(`  image : HTTP ${r.code}`);
    if (!r.ok) bloquant(`${cle} — image ${img} non servie (HTTP ${r.code}). La publication partirait sans visuel.`);
  }

  // ── STAGING : le contrôle qui manquait le 19/08 (10e échec) ──────────────
  // perfeco-bascule-mardi-w34 s'est exécutée, s'est marquée terminée, et n'a rien
  // écrit. Un staging dont la date est atteinte sans avoir été promu = bascule ratée.
  const dossier = dirname(f.file);
  const prefixe = basename(f.prefixe_staging);
  const stagings = readdirSync(dossier)
    .filter((n) => n.startsWith(prefixe) && n.endsWith('.json'))
    .map((n) => `${dossier}/${n}`);

  let couvertParStaging = false;

  for (const s of stagings) {
    const sj = chargerJson(s);
    if (!sj.ok) { bloquant(`${cle} — staging ${s} illisible : ${sj.erreur}`); continue; }
    const sd = sj.data.date_prevue;
    const jrs = sd ? ecartJours(today, sd) : null;
    dire(`  staging ${basename(s)} : date_prevue=${sd ?? 'ABSENT'}${jrs === null ? '' : ` (dans ${jrs} j)`}`);

    if (!sd) { bloquant(`${cle} — staging ${s} sans date_prevue.`); continue; }

    // Un staging qui vise la prochaine échéance signifie que le CONTENU EXISTE.
    // Le risque restant n'est plus la production, c'est la bascule.
    if (sd === prochaine) couvertParStaging = true;

    if (sd === datePrevue) {
      alerter(`${cle} — ${basename(s)} a déjà été basculé dans ${basename(f.file)} ; ce résidu peut être supprimé.`);
    } else if (jrs !== null && jrs <= 1 && sd !== datePrevue) {
      bloquant(`${cle} — ${basename(s)} vise le ${sd} (dans ${jrs} j) mais ${basename(f.file)} porte ${datePrevue}. La bascule n'a pas eu lieu. ⚠️ Une tâche de bascule peut se marquer « exécutée » sans rien écrire (constaté le 19/08/2026) : vérifier le fichier, jamais le statut de la tâche.`);
    }
  }

  // ── FRAÎCHEUR / RÈGLE J-7 ────────────────────────────────────────────────
  // Évalué APRÈS le staging : un contenu prêt mais pas encore basculé est préparé.
  // Sans cette distinction, le contrôle criait au loup sur chaque staging en attente
  // (faux positif constaté au premier essai, 21/08/2026).
  if (datePrevue === prochaine) {
    dire('  ✅ prêt pour la prochaine échéance');
  } else if (couvertParStaging) {
    dire(`  ✅ contenu du ${prochaine} prêt en staging — reste la bascule à surveiller`);
  } else if (datePrevue && ecartJours(today, datePrevue) < 0) {
    if (restant <= seuil) {
      bloquant(`${cle} — ${f.file} porte encore ${datePrevue} (date passée), aucun staging ne couvre le ${prochaine}, et la diffusion est dans ${restant} j. La routine ${f.routine} n'a rien produit. Cause la plus fréquente : jeton OAuth Claude expiré au déclenchement — la tâche démarre, meurt au 1er appel d'outil, et ne peut pas alerter.`);
    } else {
      alerter(`${cle} — contenu périmé (${datePrevue}), échéance du ${prochaine} encore à ${restant} j.`);
    }
  } else if (datePrevue) {
    dire(`  ℹ️ contenu en avance sur ${datePrevue}`);
  }

  // `pret` / `staging` sont exposés pour le contrôle du registre central plus bas :
  // ils disent l'état RÉEL constaté dans les fichiers, seul juge du statut déclaré.
  echeances.push({ cle, prochaine, canaux: f.canaux, pret: datePrevue === prochaine, staging: couvertParStaging });
  dire('');
}

// ── JOURNAL : quel traitement en dernier, quand, avec quel résultat ─────────
// Répond à la demande de Jean-Michel du 21/08/2026. Le `lastRunAt` de Cowork
// prouve un déclenchement ; ce journal prouve un EFFET, parce qu'une routine
// n'écrit sa ligne qu'en fin d'exécution. Une routine morte n'écrit rien —
// l'absence de ligne est le signal. Voir automation-agent/JOURNAL.md.
dire('──── Dernier traitement de chaque routine ────');
const JOURNAL = 'automation-agent/journal-executions.jsonl';
const dernieres = new Map();

if (!existsSync(JOURNAL)) {
  alerter(`Journal ${JOURNAL} absent — aucune routine ne trace ses exécutions.`);
} else {
  const lignes = readFileSync(JOURNAL, 'utf8').split('\n').filter((l) => l.trim());
  let malformees = 0;
  for (const [i, l] of lignes.entries()) {
    try {
      const e = JSON.parse(l);
      if (!e.routine || !e.fin_nc) { malformees++; continue; }
      const prec = dernieres.get(e.routine);
      if (!prec || e.fin_nc > prec.fin_nc) dernieres.set(e.routine, e);
    } catch {
      malformees++;
      alerter(`Journal — ligne ${i + 1} illisible, ignorée.`);
    }
  }
  dire(`  ${lignes.length} enregistrement(s), ${dernieres.size} routine(s) tracée(s)${malformees ? `, ${malformees} ligne(s) malformée(s)` : ''}`);
}

for (const [nom, r] of Object.entries(calendrier.routines ?? {})) {
  if (nom.startsWith('_')) continue;
  const e = dernieres.get(nom);

  if (!e) {
    alerter(`${nom} — jamais tracée dans le journal (cadence : ${r.cadence}). Soit elle n'écrit pas encore sa ligne de fin, soit elle n'aboutit pas.`);
    dire(`  ${nom.padEnd(30)} —  jamais tracée`);
    continue;
  }

  const jour = e.fin_nc.slice(0, 10);
  const silence = ecartJours(jour, today);
  const etat = silence > r.tolerance_jours ? '⛔' : '✅';
  dire(`  ${nom.padEnd(30)} ${etat} ${e.fin_nc.slice(0, 16).replace('T', ' ')} — ${e.resultat} — ${String(e.effet).slice(0, 60)}`);

  if (silence > r.tolerance_jours) {
    bloquant(`${nom} — silencieuse depuis ${silence} j (dernier traitement le ${jour}, tolérance ${r.tolerance_jours} j, cadence ${r.cadence}). Une routine qui meurt au 1er appel d'outil n'écrit rien : ce silence peut être le seul symptôme.`);
  }
  if (e.resultat === 'echec') {
    alerter(`${nom} — son dernier traitement (${jour}) est un ÉCHEC : ${e.effet}${e.alerte ? ` — ${e.alerte}` : ''}`);
  } else if (e.alerte) {
    alerter(`${nom} — alerte laissée le ${jour} : ${e.alerte}`);
  }
}
dire('');

// ── ESPACEMENT : collisions prévues entre deux échéances ────────────────────
dire('──── Espacement des publications ────');
const maxJour = calendrier.espacement?.max_par_jour_company_page ?? 1;
const parDate = {};
for (const e of echeances) {
  (parDate[e.prochaine] ??= []).push(e.cle);
}
for (const [d, cles] of Object.entries(parDate)) {
  if (cles.length > maxJour) {
    alerter(`Espacement — ${cles.join(' et ')} tombent tous deux le ${d}. Règle du 17/08 : jamais plus de ${maxJour} post/jour sur la Company Page.`);
  }
}
dire(`  ${Object.keys(parDate).length} date(s) d'échéance distincte(s) — aucune collision programmée détectée.`);
dire('');

// ── REGISTRE CENTRAL DES PUBLICATIONS ───────────────────────────────────────
// Ajouté le 21/08/2026, à la demande de Jean-Michel : « il y a trop de routines
// Claude Work et Claude Code qui agissent de manière indépendante ».
//
// Ce bloc comble le trou que le contrôle signalait lui-même jusqu'ici : une
// publication faite HORS pipeline lui était invisible. Elle est désormais
// inscrite au registre, donc visible d'ici — et opposable à l'espacement.
dire('──── Registre central des publications ────');
// (chargé plus haut : c'est lui qui a fourni la date de chaque prochaine diffusion)
if (!regf.ok) {
  bloquant(`${REGISTRE} illisible : ${regf.erreur}. C'est la source unique que consultent toutes les routines de publication — sans lui, chacune recalcule sa date dans son coin, ce qui est exactement ce qu'on a cherché à faire cesser.`);
} else {
  const pubs = regf.data.publications ?? [];
  const aVenir = pubs.filter((p) => p.date_nc >= today);
  dire(`  ${pubs.length} publication(s) enregistrée(s), dont ${aVenir.length} à venir.`);

  // 1. Le registre a-t-il dérivé de la réalité des files d'attente ?
  //    Le statut y est censé être recalculé, jamais déclaré : toute divergence
  //    signale soit un -Rafraichir jamais lancé, soit une saisie manuelle.
  for (const e of echeances) {
    const p = aVenir.find((x) => x.date_nc === e.prochaine && x.format === e.cle);
    if (!p) {
      alerter(`Registre — aucune entrée pour l'échéance ${e.cle} du ${e.prochaine}. Les routines qui lisent le registre ne la verront pas. Ajouter l'entrée, ou lancer planning.ps1 -Rafraichir.`);
      continue;
    }
    const reel = e.pret ? 'en_file' : e.staging ? 'en_staging' : 'prevu';
    if (p.statut !== reel && !String(p.statut).startsWith('publie')) {
      alerter(`Registre — ${e.cle} du ${e.prochaine} : le registre dit « ${p.statut} », les fichiers disent « ${reel} ». Le statut doit être recalculé (planning.ps1 -Rafraichir), jamais saisi.`);
    }
  }

  // 2. Échéances passées jamais marquées publiées : une diffusion a pu être perdue.
  for (const p of pubs) {
    if (p.date_nc < today && !String(p.statut).startsWith('publie') && p.statut !== 'annule') {
      const age = ecartJours(p.date_nc, today);
      bloquant(`Registre — la publication « ${p.sujet || p.id} » était prévue le ${p.date_nc} (il y a ${age} j) et n'est toujours pas marquée publiée (statut « ${p.statut} »). Soit elle n'est jamais partie, soit personne n'a clos son suivi.`);
    }
  }

  // 3. Espacement, en tenant compte des publications MANUELLES.
  //    C'est ce que le pipeline seul ne pouvait pas voir : le 21/08/2026, un post
  //    publié à la main est parti 2 h avant la veille éco, sur les mêmes canaux.
  const parJour = {};
  for (const p of pubs) {
    if (p.statut === 'annule') continue;
    const surCompany = (p.canaux ?? []).includes('linkedin_company');
    if (surCompany) (parJour[p.date_nc] ??= []).push(p);
  }
  for (const [d, liste] of Object.entries(parJour)) {
    if (liste.length <= maxJour) continue;
    const quoi = liste.map((x) => x.format).join(', ');
    // Bloquant seulement si la collision est ENCORE ÉVITABLE. Une collision déjà
    // survenue est un fait acquis : la signaler en erreur ferait échouer ce contrôle
    // tous les jours sur quelque chose que personne ne peut plus corriger — et un
    // filet qui échoue en permanence cesse d'être lu.
    if (d > today) {
      bloquant(`Espacement — ${liste.length} publications sur la Company Page prévues le ${d} : ${quoi}. Règle du 17/08 : jamais plus de ${maxJour} par jour. C'est encore évitable : décaler l'une des deux.`);
    } else {
      alerter(`Espacement — ${liste.length} publications sur la Company Page le ${d} : ${quoi}. Déjà survenu, non corrigeable ; à prendre en compte en lisant les statistiques de la semaine.`);
    }
  }

  const manuelles = pubs.filter((p) => p.statut === 'publie_hors_pipeline');
  if (manuelles.length) {
    dire(`  ${manuelles.length} publication(s) hors pipeline enregistrée(s) — désormais visibles de ce contrôle :`);
    for (const m of manuelles) dire(`    ${m.date_nc} — ${m.sujet ?? m.id}`);
  }
}
dire('');

// ── Bilan ───────────────────────────────────────────────────────────────────
dire('════════ Bilan ════════');
for (const a of avertissements) console.log(`::warning::${a}`);
for (const a of anomalies) console.error(`::error::${a}`);

if (anomalies.length === 0) {
  dire(`✅ Aucune anomalie bloquante. ${avertissements.length} avertissement(s).`);
  process.exit(0);
}
console.error(`::error::${anomalies.length} anomalie(s) bloquante(s). Ce contrôle est le SEUL filet indépendant de Cowork — ne pas l'ignorer.`);
process.exit(1);
