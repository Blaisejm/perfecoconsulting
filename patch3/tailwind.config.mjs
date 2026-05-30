/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,ts,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        // Palette officielle PerfEco — alignée LinkedIn
        navy: {
          DEFAULT: '#2E5DB3',  // Bleu royal PerfEco (fond posts LinkedIn)
          dark: '#1A3A7A',     // Bleu foncé (hero, footer)
          light: '#4A7FD4',    // Bleu clair
        },
        teal: {
          DEFAULT: '#EF7B00',  // Orange PerfEco (flèche, accents, chiffres clés)
          light