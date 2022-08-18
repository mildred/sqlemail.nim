import templates

func login_form*(): string = tmpli html"""
  <article>
    <form method="POST" action="/login">
      <input type="email" name="email" placeholder="email" />
      <input type="submit" value="Log-In"/>
    </form>
  </article>
  """


