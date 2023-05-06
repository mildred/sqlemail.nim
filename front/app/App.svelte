<script>
  // vim: ft=html

  import { API } from './api.js'
  import { session } from './stores.js'

  const api = new API(new URL('/', window.location).toString(), session)
  let sess = ''

  api.request_session().then(s => {
    sess = JSON.stringify(s, null, '  ')
  })

  let hello = "World"
</script>

<h1>Hello {hello}</h1>

<pre>{sess}</pre>
