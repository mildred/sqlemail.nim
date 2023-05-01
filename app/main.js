import './style.css'
import App from './App.svelte'

const app_div = document.createElement('div')

const app = new App({
  target: app_div,
})

document.body.append(app_div)

export default app

