module.exports = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx}",
    "./components/**/*.{js,ts,jsx,tsx}",
    "./TW_components/**/*.{js,ts,jsx,tsx}",
  ],
  theme: 
  {
    screens: {
      sm:'480px',
      md: '786px',
      lg: '976px',
      xl: '1440px',
    },

    colors: {
      black: {
        1: '#161616',
        2: '#1A1A1A'
      },
      white: {
        1: '#FFFFFF'
      },
      orange: {
        1: '#FAAE38',
        2: '#FBB74E'
      },
      gray: {
        1: '#444444'
      },
      blue: {
        1: '#3B75E6'
      },
    },
    extend: {
      fontFamily: {
        'inter': ['Inter', 'sans-serif'] 
      },
    },
  },
  plugins: [],
}