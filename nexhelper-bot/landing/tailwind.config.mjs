/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        // Primary: Teal/Cyan - wirkt organisiert, vertrauenswürdig
        brand: {
          DEFAULT: '#0D9488', // teal-600
          dark: '#0F766E', // teal-700
          light: '#14B8A6', // teal-500
          50: '#F0FDFA',
          100: '#CCFBF1',
          200: '#99F6E4',
        },
        surface: '#0F172A', // slate-900
        'surface-light': '#1E293B', // slate-800
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      boxShadow: {
        'soft': '0 2px 15px -3px rgba(0, 0, 0, 0.07), 0 10px 20px -2px rgba(0, 0, 0, 0.04)',
        'floating': '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
        'glow': '0 0 40px -10px rgba(13, 148, 136, 0.3)',
      },
      animation: {
        'float': 'float 6s ease-in-out infinite',
        'float-delayed': 'float 6s ease-in-out 2s infinite',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-20px)' },
        },
      },
    },
  },
  plugins: [
    require('@tailwindcss/typography'),
  ],
}
