import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import tailwindcss from "@tailwindcss/postcss";
import compression from "vite-plugin-compression";

export default defineConfig({
  root: ".",
  base: "/iso-8601-test-suite/",
  plugins: [
    vue(),
    compression({ algorithm: "gzip", threshold: 1024, ext: ".gz" }),
  ],
  css: {
    postcss: {
      plugins: [tailwindcss()],
    },
  },
  server: { port: 3000, historyApiFallback: true },
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
