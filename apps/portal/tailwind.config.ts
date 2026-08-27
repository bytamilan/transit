import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: "#1E40AF",
          light: "#3B82F6",
        },
      },
    },
  },
  plugins: [],
};

export default config;
