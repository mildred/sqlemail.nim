import templates

func logout_form*(): string = tmpli html"""
  <article>
    <form method="POST" action="/logout">
      <input type="submit" value="Log-Out"/>
    </form>
  </article>
  """


