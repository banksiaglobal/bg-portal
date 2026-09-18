import { fileURLToPath, URL } from 'node:url';

import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import tailwindcss from '@tailwindcss/vite';

// Output lands in the CSP application folder; pages reference ui/assets/index.{js,css}.
export default defineConfig(({ mode }) => ({
  root: 'src/vue',
  // Relative asset URLs: the bundle is served from a CSP app path, not the site root.
  base: './',
  plugins: [vue({ features: { optionsAPI: true } }), tailwindcss()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src/vue', import.meta.url)),
      // Templates ship as strings inside the page and are compiled in the browser.
      vue: 'vue/dist/vue.esm-bundler.js',
    },
  },
  // IRIS serves the CSS as ISO-8859-1, so keep non-ASCII (icon codepoints) as escapes.
  esbuild: { charset: 'ascii' },
  build: {
    minify: mode != 'development',
    sourcemap: mode != 'development',
    outDir: '../csp/portal/ui',
    emptyOutDir: true,
    rollupOptions: {
      output: {
        entryFileNames: 'assets/[name].js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: 'assets/[name].[ext]',
      },
    },
  },
}));
