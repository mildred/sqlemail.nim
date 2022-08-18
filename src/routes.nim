import prologue

import ./controllers / [login,errors]

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
  app.registerErrorHandler(Http404, go404)

