/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,ts,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        // UN SEUL BLEU pour tout le site (06/10/2026) : celui des visuels de
        // campagne V2, pour qu'un visiteur venu de LinkedIn ne change pas de
        // bleu. Les nuances se font par transparence (bg-navy/10), jamais par
        // une seconde valeur. Il n'y a volontairement ni navy-dark ni navy-light.
        navy: '#163D78',
        teal: {
          DEFAULT: '#EF7B00',
          light: '#F59432',
          dark: '#C86500',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
