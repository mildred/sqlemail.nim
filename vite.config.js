import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import { existsSync } from 'node:fs';

// https://vitejs.dev/config/
export default defineConfig({
  root: 'app',
  //publicDir: process.cwd() + '/vite-public',
  plugins: [svelte()],
  server: {
    proxy: {
      "/.well-known/disputatio/": "http://127.0.0.1:8080/.well-known/disputatio/",
      "/": {
        target: "http://127.0.0.1:8080/",
        bypass(req, res, opts) {
          if (req.url.startsWith("/@vite/") || req.url.startsWith("/@fs/")) {
            return req.url
          }
          let path = "app" + req.url
          if (path.endsWith('/')) path += 'index.html'
          if (existsSync(path)) {
            return req.url
          }
        }
      }
    }
  }
})

