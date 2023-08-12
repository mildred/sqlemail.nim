<script>
  // vim: ft=html

  import { API } from './api.js'
  import { session } from './stores.js'

  const api = new API(new URL('/', window.location).toString(), session)
  let sess = ''
  let count_email = null
  let first_email = ''

  api.request_session().then(async s => {
    sess = JSON.stringify(s, null, '  ')
    count_email = await api.sql("SELECT count(*) from email;")
    let res = await api.sql("SELECT raw from raw_email LIMIT 1;")
    first_email = res.rows[0][0]
  })

  let hello = "World"
</script>

<h1>Hello {hello}</h1>

<pre>{sess}</pre>

<pre>{JSON.stringify(count_email, null, '  ')}</pre>

<pre>{first_email}</pre>

