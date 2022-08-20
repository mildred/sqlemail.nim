import templates

func error_page*(message: string): string = tmpli html"""
  <article>
    <p>$message</p>
  </article>
  """


