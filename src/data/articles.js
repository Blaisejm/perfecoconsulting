// ---------------------------------------------------------------------------
// LES ARTICLES — source unique, deux langues
//
// Créé le 06/10/2026. Avant ce fichier, les articles étaient décrits DEUX fois :
// une liste de données dans src/pages/ressources.astro et du HTML écrit à la
// main dans src/pages/en/resources.astro. Rien ne retenait les deux ensemble, et
// elles avaient divergé : l'index anglais renvoyait vers deux pages qui
// n'existent pas (voir SANS_VERSION_ANGLAISE plus bas).
//
// Règle que ce fichier rend vérifiable : un article existe en français ET en
// anglais. L'absence de la clé `en` est la seule façon de déclarer un manque, et
// scripts/verifier-articles.mjs la signale.
//
// Classement : `porte` est le filtre principal, `secteurs` le filtre secondaire.
// L'ancien champ `categorie` (Pilotage, Gouvernance, Exécution…) n'est pas repris :
// c'est le vocabulaire métier retiré le 06/10/2026.
// ---------------------------------------------------------------------------

/** Les trois portes d'entrée du site, plus les articles qui situent le contexte. */
export const portes = {
  'un-service': {
    fr: 'Un service',
    en: 'One department',
  },
  'plusieurs-services': {
    fr: 'Plusieurs services',
    en: 'Several departments',
  },
  'projet-a-plusieurs': {
    fr: 'Un projet à plusieurs',
    en: 'A joint project',
  },
  contexte: {
    fr: 'Le contexte',
    en: 'Context',
  },
};

/** Les secteurs, repris de la page /secteurs. Filtre secondaire. */
export const secteurs = {
  'industrie-energie': { fr: 'Industrie & Énergie', en: 'Industry & Energy' },
  btp: { fr: 'BTP & Maintenance', en: 'Construction & Maintenance' },
  banque: { fr: 'Banque & Assurances', en: 'Banking & Insurance' },
  public: { fr: 'Secteur public & Parapublic', en: 'Public sector' },
};

// Un article sans secteur (`secteurs: []`) s'affiche dans tous les filtres.
// C'est le cas des 17 articles existants : aucun n'a été écrit pour un secteur
// en particulier, et leur en attribuer un après coup serait une invention.

/**
 * Les séries éditoriales. L'index anglais affichait « Series · 6/8 » pour deux
 * articles de séries différentes — ici le nom de la série est porté une fois.
 */
export const series = {
  'execution-strategique': {
    total: 8,
    fr: 'Exécution Stratégique',
    en: 'Strategic Execution',
  },
  'rythme-pilotage': {
    total: 8,
    fr: 'Le Rythme de Pilotage',
    en: 'The Management Rhythm',
  },
};

/**
 * Les articles, du plus récent au plus ancien.
 *
 * porte     — une clé de `portes`. Filtre principal.
 * secteurs  — zéro à plusieurs clés de `secteurs`. Filtre secondaire.
 * date      — AAAA-MM-JJ, la même dans les deux langues.
 * serie     — { id, numero } ou { id, horsSerie: true }. Facultatif.
 * fr / en   — { slug, titre, extrait }. `en` absente = pas encore traduit.
 */
export const articles = [
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-10-06',
    serie: { id: 'rythme-pilotage', numero: 6 },
    fr: {
      slug: 'remonter-information-sans-la-deformer',
      titre: "Remonter l'information sans la déformer",
      extrait: "46 % des dirigeants interrogés disent manquer de retours honnêtes dans leur entreprise. Plus de rapports n'y change rien : une page, trois temps — où on en est, les options, une recommandation — et le degré de certitude de chaque chiffre.",
    },
    en: {
      slug: 'reporting-up-without-distortion',
      titre: 'Reporting up without distortion',
      extrait: '46% of executives surveyed say they lack honest feedback across their own company. More reports will not fix it: one page, three parts — where we stand, the options, one recommendation — and the level of certainty of every figure.',
    },
  },
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-09-29',
    serie: { id: 'rythme-pilotage', numero: 5 },
    fr: {
      slug: 'le-point-hebdomadaire-qui-tranche',
      titre: 'Le point hebdomadaire qui tranche vraiment',
      extrait: "87 % des salariés disent manquer de temps pour se coordonner, chacun étant pris par ses dossiers. Le point hebdomadaire existe déjà presque partout — il lui manque cinq minutes à la fin. Quarante-cinq minutes, quatre rubriques, trois lignes écrites.",
    },
    en: {
      slug: 'the-weekly-meeting-that-actually-decides',
      titre: 'The weekly meeting that actually decides',
      extrait: '87% of employees say they lack the time to coordinate, each absorbed by their own workload. The weekly meeting already exists almost everywhere — what it lacks is its last five minutes. Forty-five minutes, four sections, three written lines.',
    },
  },
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-09-22',
    serie: { id: 'rythme-pilotage', numero: 4 },
    fr: {
      slug: 'faire-descendre-les-priorites',
      titre: 'Faire descendre les priorités sans bureaucratie',
      extrait: "56 % des dirigeants du COMEX sont au clair sur leurs priorités décisives. Deux étages plus bas, ils ne sont plus que 27 %. L'écart n'est pas dans la stratégie, il est dans sa transmission — et quatre choses suffisent à le combler.",
    },
    en: {
      slug: 'making-priorities-reach-the-front-line',
      titre: 'Making priorities reach the front line',
      extrait: '56% of C-suite leaders are clear on their must-win priorities. Two levels down, only 27% are. The gap is not in the strategy — it is in how the strategy travels. Four concrete things close it.',
    },
  },
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-09-15',
    serie: { id: 'rythme-pilotage', numero: 3 },
    fr: {
      slug: 'le-journal-de-decision',
      titre: 'Le journal de décision',
      extrait: "Le même sujet revient pour la troisième séance de suite. Il avait été tranché, mais plus personne ne retrouve ce qui avait été décidé ni sur quoi. Les quatre lignes qui rendent une décision retrouvable six mois plus tard.",
    },
    en: {
      slug: 'the-decision-log',
      titre: 'The decision log',
      extrait: 'The same item is back for the third meeting running. It was settled months ago, but nobody can find what was decided, or on what basis. The four lines that keep a decision findable six months later.',
    },
  },
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-09-08',
    serie: { id: 'rythme-pilotage', numero: 2 },
    fr: {
      slug: 'choisir-les-indicateurs-qui-comptent',
      titre: 'Choisir les 3 à 5 indicateurs qui comptent',
      extrait: "Un tableau de bord ne souffre pas d'un indicateur manquant, mais de trente-cinq indicateurs de trop. Les trois questions qui décident si une ligne reste ou sort, et la règle « un entre, un sort » qui empêche le tableau de regrossir.",
    },
    en: {
      slug: 'choosing-the-few-metrics-that-matter',
      titre: 'Choosing the 3 to 5 metrics that matter',
      extrait: 'A dashboard rarely suffers from a missing metric. It suffers from thirty-five too many. The three questions that decide whether a line stays or goes, and the "one in, one out" rule that stops the dashboard growing back.',
    },
  },
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-09-01',
    serie: { id: 'rythme-pilotage', numero: 1 },
    fr: {
      slug: 'installer-un-rythme-de-pilotage',
      titre: "Le rythme de pilotage, qu'est-ce que c'est vraiment ?",
      extrait: "Le plan, le séminaire, le groupe de travail remobilisent pour quelques semaines, puis tout retombe. Ce qui installe un changement, c'est ce qui revient à date fixe. Les 4 marqueurs d'un rythme de pilotage, et par où commencer.",
    },
    en: {
      slug: 'building-a-management-rhythm-that-lasts',
      titre: 'What a management rhythm actually is',
      extrait: 'The offsite, the action plan, the working group all mobilise people for a few weeks, then everything fades. What makes change stick is what comes back on a fixed date. The four markers of a real management rhythm, and where to start.',
    },
  },
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-08-25',
    serie: { id: 'execution-strategique', numero: 8 },
    fr: {
      slug: 'remettre-organisation-au-service-strategie',
      titre: "Remettre l'organisation au service de la stratégie",
      extrait: "Fin de la série Exécution Stratégique. Sept constats, une seule cause : l'organisation est construite pour fonctionner, pas pour exécuter. Les 4 alignements à traiter — décider, rythmer, voir, mesurer — dans cet ordre.",
    },
    en: {
      slug: 'realigning-the-organisation-behind-the-strategy',
      titre: 'Realigning the organisation behind the strategy',
      extrait: 'The final article of the series. Seven findings, one cause: the organisation is built to run, not to execute. The four alignments to fix — deciding, pacing, seeing, measuring — in that order.',
    },
  },
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-08-18',
    serie: { id: 'execution-strategique', numero: 7 },
    fr: {
      slug: 'les-kpi-ne-font-pas-la-performance',
      titre: 'Les KPI ne font pas la performance',
      extrait: "Moins de 25 % des organisations obtiennent une amélioration durable de leur performance (McKinsey, 2026). Mesurer n'est pas piloter : ce qui fait la performance, ce n'est pas l'indicateur, c'est la décision qu'il déclenche.",
    },
    en: {
      slug: 'kpis-do-not-create-performance',
      titre: 'KPIs do not create performance',
      extrait: 'Fewer than 25% of organisations achieve sustained performance improvement (McKinsey, 2026). Measuring is not steering: what creates performance is not the metric, but the decision it triggers.',
    },
  },
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-08-11',
    serie: { id: 'execution-strategique', numero: 6 },
    fr: {
      slug: 'le-comex-manque-de-visibilite',
      titre: 'Le COMEX manque souvent de visibilité',
      extrait: "75 % des dirigeants ne font pas confiance aux données sur lesquelles ils s'appuient pour décider (Gartner, 2025). Chaque niveau hiérarchique filtre, résume et adoucit l'information avant qu'elle n'atteigne le comité.",
    },
    en: {
      slug: 'the-executive-committee-often-lacks-visibility',
      titre: 'Executive committees often lack visibility',
      extrait: "75% of executives say they don't trust the data they rely on to make decisions (Gartner, 2025). At every level of the hierarchy, information gets filtered, softened, and summarized before it ever reaches the boardroom.",
    },
  },
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-08-04',
    serie: { id: 'execution-strategique', numero: 5 },
    fr: {
      slug: 'les-reunions-ne-remplacent-pas-le-pilotage',
      titre: 'Les réunions ne remplacent pas le pilotage',
      extrait: "Un cadre dirigeant passe en moyenne 23 h par semaine en réunion. Un seul comité de direction hebdomadaire peut mobiliser jusqu'à 300 000 heures par an en cascade. Multiplier les réunions ne garantit pas qu'on pilote quoi que ce soit.",
    },
    en: {
      slug: 'meetings-dont-replace-steering',
      titre: "Meetings don't replace steering",
      extrait: "An executive spends an average of 23 hours a week in meetings. A single weekly Executive Committee meeting can cascade into up to 300,000 hours of work a year. More meetings don't guarantee you're steering anything.",
    },
  },
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-07-28',
    serie: { id: 'execution-strategique', numero: 4 },
    fr: {
      slug: 'pourquoi-les-projets-ralentissent',
      titre: 'Pourquoi les projets ralentissent — et ce qui les fait vraiment dérailler',
      extrait: "91,5 % des mégaprojets dépassent budget ou délai. Ce n'est presque jamais un problème de compétence. 4 signaux annoncent, souvent des mois à l'avance, qu'un projet va ralentir.",
    },
    en: {
      slug: 'why-projects-slow-down',
      titre: 'Why projects slow down — what really derails them',
      extrait: "91.5% of megaprojects go over budget or over schedule. It's almost never a skills problem. 4 signals foreshadow a project that's about to slow down.",
    },
  },
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-07-21',
    serie: { id: 'execution-strategique', horsSerie: true },
    fr: {
      slug: 'qui-a-le-droit-de-decider',
      titre: "Qui a vraiment le droit de décider ? L'angle mort de la gouvernance des COMEX",
      extrait: "Un organigramme et une matrice RACI ne suffisent pas à faire fonctionner la décision. 4 erreurs récurrentes expliquent pourquoi les bonnes personnes n'ont, dans les faits, pas le pouvoir de trancher.",
    },
    en: {
      slug: 'who-really-has-the-right-to-decide',
      titre: 'Who really has the right to decide? The blind spot in executive committee governance',
      extrait: "An org chart and a RACI matrix aren't enough to make decisions work. 4 recurring mistakes explain why the right people often don't actually hold the power to decide.",
    },
  },
  {
    porte: 'contexte',
    secteurs: [],
    date: '2026-07-15',
    serie: { id: 'execution-strategique', numero: 3 },
    fr: {
      slug: 'la-richesse-ne-suffit-pas',
      titre: 'La richesse ne suffit pas : ce que les organisations les plus performantes ont compris',
      extrait: "Zurich, Singapour, Copenhague : leur avantage n'est pas seulement financier, il est organisationnel. 4 leviers séparent les organisations à haut rendement des autres.",
    },
    en: {
      slug: 'wealth-is-not-enough',
      titre: 'Wealth is not enough: what the highest-performing organisations understood',
      extrait: "Zurich, Singapore, Copenhagen: their real advantage isn't only financial — it's organisational. 4 levers separate high-performing organisations from the rest.",
    },
  },
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-07-07',
    serie: { id: 'execution-strategique', numero: 2 },
    fr: {
      slug: 'une-strategie-ne-suffit-pas',
      titre: "Une stratégie ne suffit pas : l'exécution comme avantage concurrentiel",
      extrait: "40 % de la valeur stratégique est perdue à l'étape de l'exécution (HBR). Les organisations « saines » sont 3× plus performantes sur le long terme (McKinsey). Les 4 piliers de l'exécution rigoureuse.",
    },
    en: {
      slug: 'strategy-alone-is-not-enough',
      titre: 'Strategy alone is not enough: execution as a competitive advantage',
      extrait: 'Harvard Business Review estimates that 40% of strategic value is lost at the execution stage. McKinsey confirms: healthy organisations are 3× more likely to outperform. The 4 pillars of rigorous execution.',
    },
  },
  {
    porte: 'plusieurs-services',
    secteurs: [],
    date: '2026-06-30',
    serie: { id: 'execution-strategique', numero: 1 },
    fr: {
      slug: 'plans-strategiques-execution',
      titre: "Pourquoi les plans stratégiques n'aboutissent pas — alors que la stratégie est souvent la bonne",
      extrait: "Une stratégie solide ne suffit pas. L'exécution est la compétence rare et décisive. Symptômes, causes et 4 leviers pour rapprocher stratégie et résultats concrets dans votre organisation.",
    },
    en: {
      slug: 'why-strategic-plans-fail',
      titre: 'Why strategic plans fail to deliver — even when the strategy is sound',
      extrait: 'A solid strategy is not enough. Execution is the rare and decisive competence. Symptoms, root causes and 4 levers to bridge strategy and concrete results in your organisation.',
    },
  },
  {
    porte: 'un-service',
    secteurs: [],
    date: '2026-06-23',
    // Pas de clé `en` : l'article n'existe pas en anglais. L'index anglais
    // renvoyait pourtant vers /en/resources/standard-file-escalation-criteria,
    // qui est en 404 depuis la mise en ligne.
    fr: {
      slug: 'qualification-dossier-escalade-management',
      titre: 'Un dossier est-il encore standard ? Les 3 critères que tout manager doit maîtriser',
      extrait: "Un dossier cesse d'être standard dès qu'il dépasse le cadre habituel en complexité, en montant ou en risque. Trois critères simples pour éviter les erreurs de qualification.",
    },
  },
  {
    porte: 'contexte',
    secteurs: [],
    date: '2026-06-18',
    // Pas de clé `en` : l'article n'existe pas en anglais. L'index anglais
    // renvoyait pourtant vers /en/resources/geopolitical-volatility-advantage,
    // qui est en 404 depuis la mise en ligne.
    fr: {
      slug: 'volatilite-geopolitique-avantage-comex',
      titre: 'Volatilité géopolitique : 5 leviers pour en faire un avantage compétitif',
      extrait: "L'instabilité est devenue structurelle. Comment les COMEX peuvent transformer cette contrainte en avantage ? Lecture PerfEco d'un article McKinsey Quarterly.",
    },
  },
];

// --- Lectures ---------------------------------------------------------------

/** Les articles d'une langue, prêts à afficher. Ceux qui manquent sont écartés. */
export function articlesDe(langue) {
  return articles
    .filter(a => a[langue])
    .map(a => ({
      ...a[langue],
      porte: a.porte,
      porteLibelle: portes[a.porte][langue],
      secteurs: a.secteurs,
      date: a.date,
      serie: a.serie
        ? {
            nom: series[a.serie.id][langue],
            libelle: a.serie.horsSerie
              ? series[a.serie.id][langue] + (langue === 'fr' ? ' · Hors-série' : ' · Special edition')
              : `${series[a.serie.id][langue]} · ${a.serie.numero}/${series[a.serie.id].total}`,
          }
        : null,
      lien: langue === 'fr' ? `/ressources/${a.fr.slug}` : `/en/resources/${a.en.slug}`,
    }));
}

/** Les articles qui n'existent pas encore en anglais. */
export const SANS_VERSION_ANGLAISE = articles.filter(a => !a.en).map(a => a.fr.slug);
