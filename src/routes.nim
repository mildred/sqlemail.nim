import prologue

import ./controllers/[login,articles,errors,assets]

proc ensureLoggedIn(): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    if ctx.session["email"] == "":
      resp redirect("/login")

proc init_routes*(app: Prologue) =
  app.addRoute("/logout", login.get_logout, HttpGet)
  app.addRoute("/logout", login.post_logout, HttpPost)
  app.addRoute("/login", login.get, HttpGet)
  app.addRoute("/login", login.post, HttpPost)
  app.addRoute("/login/{email}", login.get, HttpGet)
  app.addRoute("/login/{email}/{code}", login.get, HttpGet)
  app.addRoute("/~{userguid}/", articles.index, HttpGet)
  app.addRoute("/~{userguid}/", articles.create, HttpPost)
  app.addRoute("/~{userguid}/{name}/", articles.show, HttpGet)
  app.addRoute("/~{userguid}/{name}/", articles.update, HttpPost)
  app.addRoute("/~{userguid}/{name}/edit", articles.edit, HttpGet)
  app.addRoute("/~{userguid}/{name}/.json", articles.get_json, HttpGet)
  app.addRoute("/~{userguid}/{name}/.html", articles.get_html, HttpGet)
  app.addRoute("/assets/{path}$", assets.get, HttpGet)
  app.registerErrorHandler(Http404, go404)

