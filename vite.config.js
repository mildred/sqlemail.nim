import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

// https://vitejs.dev/config/
export default defineConfig({
  root: 'app',
  //publicDir: process.cwd() + '/vite-public',
  plugins: [svelte()],
  server: {
    proxy: {
      "/.well-known/disputatio/": "http://127.0.0.1:8080/"
    }
  }
})

