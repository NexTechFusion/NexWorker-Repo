/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      colors: {
        brand: {
          DEFAULT: '#4F46E5', // Indigo 600
          dark: '#3730A3',    // Indigo 800
          light: '#818CF8',   // Indigo 400
          50: '#EEF2FF',      // Indigo 50
          900: '#1E1B4B'
        },
        surface: {
          DEFAULT: '#0F172A', // Slate 900
          light: '#1E293B',   // Slate 800
          dark: '#020617'     // Slate 950
        }
      },
      boxShadow: {
        'soft': '0 4px 20px -2px rgba(15, 23, 42, 0.05)',
        'floating': '0 20px 40px -10px rgba(15, 23, 42, 0.1)',
        'glow': '0 0 20px rgba(79, 70, 229, 0.3)',
      }
    },
  },
  plugins: [],
}
