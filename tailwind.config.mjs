/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,ts,tsx,mdx}'],
  theme: {
    extend: {
      // ÉCHELLE DE TEXTE relevée le 06/10/2026. Le site tournait à 14 px
      // (text-sm, 552 usages) et 12 px (text-xs, 428 usages) : trop petit pour
      // des lecteurs dirigeants. On relève l'échelle ICI plutôt que de reprendre
      // les 980 classes une par une — et une page qui a besoin d'autre chose
      // monte d'un cran avec la classe au-dessus, sans valeur en dur.
      // Les grands titres (4xl, 5xl) ne bougent pas : ils étaient déjà justes.
      fontSize: {
        xs:   ['0.8125rem', { lineHeight: '1.25rem' }],   // 13 px (etait 12)
        sm:   ['1rem',      { lineHeight: '1.6rem' }],    // 16 px (etait 14)
        base: ['1.0625rem', { lineHeight: '1.7rem' }],    // 17 px (etait 16)
        lg:   ['1.1875rem', { lineHeight: '1.8rem' }],    // 19 px (etait 18)
        xl:   ['1.3125rem', { lineHeight: '1.85rem' }],   // 21 px (etait 20)
        '2xl':['1.5625rem', { lineHeight: '2.05rem' }],   // 25 px (etait 24)
        '3xl':['1.9375rem', { lineHeight: '2.35rem' }],   // 31 px (etait 30)
        '4xl':['2.25rem',   { lineHeight: '2.5rem' }],    // inchange
        '5xl':['3rem',      { lineHeight: '1' }],         // inchange
      },
      colors: {
        // UN SEUL BLEU pour tout le site. C'est le bleu du logo lui-meme :
        // l'arret central des deux degrades principaux de PerfEco Logo OK.
        // Choisi parmi les huit bleus du logo parce que c'est le plus clair
        // qui garde un contraste suffisant avec le blanc (5,1:1) ; les deux
        // bleus plus clairs du logo tombent sous le seuil de lisibilite.
        // Les nuances se font par transparence (bg-navy/10), jamais par une
        // seconde valeur. Il n'y a volontairement ni navy-dark ni navy-light.
        navy: '#3870B1',
        // L'ORANGE est deja celui du logo : #EF7B00 y figure tel quel.
        // `light` est le second orange du logo, `dark` une nuance plus sombre
        // derivee pour les survols — le logo n'en contient pas.
        teal: {
          DEFAULT: '#EF7B00',
          light: '#F9B233',
          dark: '#A85400',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
