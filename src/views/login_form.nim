import templates

import ./common

func login_form*(redirect_url: string = ""): string = tmpli html"""
  <article>
    <form method="POST" action="/login">
      <input type="hidden" name="redirect_url" value="$(h(redirect_url))" />
      <input type="email" name="email" placeholder="email" />
      <input type="submit" value="Log-In"/>
    </form>
  </article>
  """


