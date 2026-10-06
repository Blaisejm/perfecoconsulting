// ---------------------------------------------------------------------------
// LES IMAGES DU SITE — catalogue unique
//
// Créé le 06/10/2026. Trois origines, trois usages distincts :
//
//   photo    — photographies professionnelles de Jean-Michel Blaise
//              (séance 6000×4000, « Comm & Marketing / Photos PROS - JMB »).
//              Ce sont de vraies photos : elles vont sur les pages qui parlent
//              de qui nous sommes et de la façon dont nous travaillons.
//
//   scene    — images de situation issues des campagnes LinkedIn publiées
//              (« Perfeco-Social-Media / images-library »). Ce sont les SOURCES
//              des carrousels : le texte est posé par le gabarit HTML, pas
//              incrusté dans l'image, donc elles se recadrent librement.
//
//   campagne — zone photographique des affiches de campagne V2 de septembre,
//              recadrée. Les affiches d'octobre portent logo et accroche
//              incrustés : elles ne sont pas réutilisables ainsi.
//
// Le texte de remplacement (`alt`) vit ici et nulle part ailleurs : une page
// qui affiche une image du catalogue n'a pas à le réécrire, donc il ne peut
// pas diverger d'une page à l'autre.
//
// ⚠️ Toute image ajoutée ici doit exister dans public/photos/, et public/photos
// est déjà dans la liste de chemins de l'`ignore` de netlify.toml — sans quoi
// une mise à jour d'image ne déclencherait aucun déploiement.
// ---------------------------------------------------------------------------

export const images = {
  // --- Jean-Michel, vraies photos ------------------------------------------
  'jmb-portrait': {
    src: '/photos/jmb-portrait-2026.jpg',
    ratio: '4/5',
    origine: 'photo',
    alt: 'Jean-Michel Blaise, fondateur de PerfEco Consulting',
  },
  'jmb-bureau': {
    src: '/photos/jmb-bureau.jpg',
    ratio: '4/5',
    origine: 'photo',
    alt: 'Jean-Michel Blaise à son bureau',
  },
  'jmb-debout': {
    src: '/photos/jmb-debout.jpg',
    ratio: '4/5',
    origine: 'photo',
    alt: 'Jean-Michel Blaise, debout dans les locaux',
  },
  'jmb-couloir': {
    src: '/photos/jmb-couloir.jpg',
    ratio: '4/5',
    origine: 'photo',
    alt: 'Jean-Michel Blaise dans un couloir de bureaux',
  },
  'jmb-atelier': {
    src: '/photos/jmb-atelier-equipe.jpg',
    ratio: '3/2',
    origine: 'photo',
    alt: "Jean-Michel Blaise anime un atelier autour d'une table de réunion",
  },
  'jmb-reunion-client': {
    src: '/photos/jmb-reunion-client.jpg',
    ratio: '3/2',
    origine: 'photo',
    alt: 'Jean-Michel Blaise en réunion avec deux interlocuteurs',
  },
  'jmb-en-action': {
    src: '/photos/jmb-en-action.jpg',
    ratio: '3/2',
    origine: 'photo',
    alt: 'Jean-Michel Blaise travaille sur écran avec un collaborateur',
  },
  'jmb-echange': {
    src: '/photos/jmb-echange.jpg',
    ratio: '3/2',
    origine: 'photo',
    alt: 'Jean-Michel Blaise en échange en face à face',
  },

  // --- Situations, campagnes LinkedIn --------------------------------------
  'equipe-alignement': {
    src: '/photos/equipe-alignement.jpg',
    ratio: '16/9',
    origine: 'scene',
    alt: "Une équipe se met d'accord autour d'une même table",
  },
  'lecture-dossier': {
    src: '/photos/lecture-dossier.jpg',
    ratio: '21/9',
    origine: 'scene',
    alt: 'Deux personnes suivent le trajet d’un dossier, document en main',
  },
  'ecrire-projet': {
    src: '/photos/ecrire-projet.jpg',
    ratio: '21/9',
    origine: 'scene',
    alt: 'Une équipe écrit ensemble les étapes d’un projet',
  },
  'conversation-couloir': {
    src: '/photos/conversation-couloir.jpg',
    ratio: '4/3',
    origine: 'scene',
    alt: 'Deux collègues échangent dans un couloir, entre deux réunions',
  },
  'comex-pacifique': {
    src: '/photos/comex-pacifique.jpg',
    ratio: '4/3',
    origine: 'scene',
    alt: 'Un comité de direction réuni dans un contexte pacifique',
  },
  'quotidien-reprend': {
    src: '/photos/quotidien-reprend.jpg',
    ratio: '4/3',
    origine: 'scene',
    alt: 'Une équipe reprend le travail quotidien dans un même service',
  },
  'tableau-grossit': {
    src: '/photos/tableau-grossit.jpg',
    ratio: '3/2',
    origine: 'scene',
    alt: 'Un tableau de bord qui ne cesse de grossir, commenté par une équipe',
  },
  'choisir-indicateurs': {
    src: '/photos/choisir-indicateurs.jpg',
    ratio: '3/2',
    origine: 'scene',
    alt: 'Une équipe choisit les quelques chiffres qui comptent',
  },
  'team-pacific': {
    src: '/photos/team-pacific.jpg',
    ratio: '16/9',
    origine: 'scene',
    alt: 'Une équipe réunie face au lagon',
  },
  'methode-consultant': {
    src: '/photos/methode-consultant.jpg',
    ratio: '3/2',
    origine: 'scene',
    alt: 'Un consultant au travail avec une équipe',
  },
  'comex-reunion': {
    src: '/photos/comex-reunion.jpg',
    ratio: '3/2',
    origine: 'scene',
    alt: 'Un comité de direction en séance',
  },
  'consultant-client': {
    src: '/photos/consultant-client.jpg',
    ratio: '4/3',
    origine: 'scene',
    alt: 'Un consultant et son client face à face',
  },

  // --- Zone photographique des affiches de campagne V2 ---------------------
  'equipe-projet': {
    src: '/photos/equipe-projet.jpg',
    ratio: '16/9',
    origine: 'campagne',
    alt: "Quatre personnes avancent ensemble sur un même sujet",
  },
  'reunion-blocage': {
    src: '/photos/reunion-blocage.jpg',
    ratio: '16/9',
    origine: 'campagne',
    alt: 'Quatre personnes réunies autour d’un même dossier',
  },
  'presentation-chiffres': {
    src: '/photos/presentation-chiffres.jpg',
    ratio: '16/9',
    origine: 'campagne',
    alt: 'Une dirigeante présente des chiffres à son équipe',
  },
  'service-au-travail': {
    src: '/photos/service-au-travail.jpg',
    ratio: '16/9',
    origine: 'campagne',
    alt: 'Une équipe au travail dans un même service',
  },
  'reunion-a-distance': {
    src: '/photos/reunion-a-distance.jpg',
    ratio: '16/9',
    origine: 'campagne',
    alt: 'Une réunion réunissant des participants sur place et à distance',
  },
  'atelier-mur': {
    src: '/photos/atelier-mur.jpg',
    ratio: '16/9',
    origine: 'campagne',
    alt: 'Une équipe construit au mur le trajet d’un dossier',
  },
};

/** Une image du catalogue. Lève si la clé n'existe pas, pour que l'erreur
 *  arrive à la compilation et non en 404 sur le site publié. */
export function image(cle) {
  const i = images[cle];
  if (!i) throw new Error(`Image inconnue dans le catalogue : « ${cle} »`);
  return i;
}
