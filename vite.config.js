import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import { existsSync } from 'node:fs';

const front_root = 'front'

// https://vitejs.dev/config/
export default defineConfig({
  root: front_root,
  //publicDir: process.cwd() + '/vite-public',
  plugins: [svelte()],
  server: {
    port: 5273,
    proxy: {
      "/.well-known/sqlemail/": "http://127.0.0.1:8080/",
      //*
      "/": {
        target: "http://127.0.0.1:8080/",
        bypass(req, res, opts) {
          if (req.url.startsWith("/@vite/") || req.url.startsWith("/@fs/")) {
            return req.url
          }
          let path = front_root + req.url.replace(/\?.*$/, '')
          if (path.endsWith('/')) path += 'index.html'
          if (existsSync(path)) {
            return req.url
          }
        }
      }
      //*/
    }
  },
  build: {
    outDir: "../assets",
    rollupOptions: {
      input: {
        app: front_root + '/app/index.html',
        oauth_response: front_root + '/app/utils/oauth_response.html'
      }
    }
  }
})

