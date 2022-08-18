import templates

func error404*(): string = tmpli html"""
  <article>
    <p>Page not found.</p>
  </article>
  """


