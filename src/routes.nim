import prologue

import ./controllers / [login]

proc ensureLoggedIn(): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    if ctx.session["email"] == "":
      resp redirect("/login")

proc init_routes*(app: Prologue) =
  app.addRoute("/login", login.get, HttpGet)
  app.addRoute("/login", login.post, HttpPost)
  app.addRoute("/login/{email}", login.get, HttpGet)
  app.addRoute("/login/{email}", login.post, HttpPost)
