import prologue

import ./controllers/[login,articles,errors,assets,groups,group_posts,home]

proc ensureLoggedIn*(): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    if ctx.session.getOrDefault("email", "") == "":
      resp redirect("/login", code = Http303)
    else:
      await switch(ctx)

proc init_routes*(app: Prologue) =
  app.addRoute("/", home.index, HttpGet, middlewares = @[ensureLoggedIn()])
  app.addRoute("/logout", login.get_logout, HttpGet)
  app.addRoute("/logout", login.post_logout, HttpPost)
  app.addRoute("/login", login.get, HttpGet)
  app.addRoute("/login", login.post, HttpPost)
  app.addRoute("/login/{email}", login.get, HttpGet)
  app.addRoute("/login/{email}/{code}", login.get, HttpGet)
  app.addRoute(re"^/(g|@)/$", groups.create, HttpPost, middlewares = @[ensureLoggedIn()])
  app.addRoute(re"^/(g:|@)(?P<groupguid>[^/]+)/$", groups.show, HttpGet, middlewares = @[ensureLoggedIn()])
  app.addRoute(re"^/(g:|@)(?P<groupguid>[^/]+)/join/$", groups.join, HttpPost, middlewares = @[ensureLoggedIn()])
  app.addRoute(re"^/(g:|@)(?P<groupguid>[^/]+)/posts/$", group_posts.create, HttpPost, middlewares = @[ensureLoggedIn()])
  app.addRoute(re"^/(u:|~)(?P<userguid>[^/]+)/$", articles.index, HttpGet, middlewares = @[ensureLoggedIn()])
  app.addRoute("/~{userguid}/", articles.create, HttpPost, middlewares = @[ensureLoggedIn()])
  app.addRoute("/~{userguid}/{name}/", articles.show, HttpGet, middlewares = @[ensureLoggedIn()])
  app.addRoute("/~{userguid}/{name}/", articles.update, HttpPost, middlewares = @[ensureLoggedIn()])
  app.addRoute("/~{userguid}/{name}/edit", articles.edit, HttpGet, middlewares = @[ensureLoggedIn()])
  app.addRoute("/~{userguid}/{name}/.json", articles.get_json, HttpGet, middlewares = @[ensureLoggedIn()])
  app.addRoute("/~{userguid}/{name}/.html", articles.get_html, HttpGet, middlewares = @[ensureLoggedIn()])
  app.addRoute("/assets/{path}$", assets.get, HttpGet)
  app.registerErrorHandler(Http404, go404)

