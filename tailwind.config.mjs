/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,ts,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        navy: {
          DEFAULT: '#2E5DB3',
          dark: '#1A3A7A',
          light: '#4A7FD4',
        },
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
