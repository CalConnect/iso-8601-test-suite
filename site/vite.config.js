import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import tailwindcss from "@tailwindcss/postcss";
import compression from "vite-plugin-compression";

export default defineConfig({
  root: ".",
  plugins: [
    vue(),
    compression({ algorithm: "gzip", threshold: 1024, ext: ".gz" }),
  ],
  css: {
    postcss: {
      plugins: [tailwindcss()],
    },
  },
  server: { port: 3000 },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vue: ["vue"],
        },
      },
    },
  },
});
