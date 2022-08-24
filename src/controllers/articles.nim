import std/json
import std/strformat
import prologue

import ./errors
import ../db/[users,articles]
import ../context
import ../convert_articles
import ../views/layout
import ../views/common
import ../views/articles as varticles

proc create*(ctx: Context) {.async, gcsafe.} =
  let user_guid = ctx.getPathParams("userguid", "")
  let name = ctx.getFormParamsOption("name").get()
  resp redirect(&"/~{user_guid}/{name}/edit")

proc index*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let user_guid = ctx.getPathParams("userguid", "")
  let user = db[].get_user(user_guid)
  if user_guid == ctx.current_user_guid():
    resp ctx.layout(article_new() & article_index(), title = "User index")
  else:
    resp ctx.layout(article_index(), title = "User index")

proc show*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let user_guid = ctx.getPathParams("userguid", "")
  let name = ctx.getPathParams("name", "")
  let user = db[].get_user(user_guid)
  if user.is_none:
    return ctx.go404()

  let art = db[].get_last_article(user.get.id, name)
  if art.is_none:
    return ctx.go404()

  let markup = art.get.to_html()
  resp ctx.layout(article_view(art.get.patch_guid, markup))

proc update*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let current_user = db[].get_user(hash_email(ctx.session.getOrDefault("email", "")))
  if current_user.is_none:
    return ctx.go403()

  let html = ctx.getFormParamsOption("html")
  if html.is_none:
    resp "Missing html parameter", Http400
    return
  let parent_patch = ctx.getFormParamsOption("parent_patch")
  if parent_patch.is_none:
    resp "Missing parent_patch parameter", Http400
    return

  let name = ctx.getPathParams("name", "")
  var article: Article
  article.name = name
  article.user_id = current_user.get.id
  article.from_html(html.get)

  db[].create_article(article, parent_patch.get)

  resp "", Http201

proc edit*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let user_guid = ctx.getPathParams("userguid", "")
  let name = ctx.getPathParams("name", "")
  let user = db[].get_user(user_guid)
  if user.is_none:
    return ctx.go404()

  var markup: string = ""
  var patch_id: string = ""
  let art = db[].get_last_article(user.get.id, name)
  if art.is_some:
    markup = art.get.to_html()
    patch_id = art.get.patch_guid
  else:
    markup = &"<h1>{h(name)}</h1>"
  resp ctx.layout(article_editor(patch_id, markup))

proc get_json*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let user_guid = ctx.getPathParams("userguid", "")
  let name = ctx.getPathParams("name", "")
  let user = db[].get_user(user_guid)
  if user.is_none:
    return ctx.go404()

  let art = db[].get_last_article(user.get.id, name)
  if art.is_none:
    return ctx.go404()

  var pars: seq[JsonNode] = @[]
  for p in art.get.paragraphs:
    pars.add(%*{"style": p.style, "text": p.text})

  resp json_response(%*{
    "paragraphs": %*pars
  })

proc get_html*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let user_guid = ctx.getPathParams("userguid", "")
  let name = ctx.getPathParams("name", "")
  let user = db[].get_user(user_guid)
  if user.is_none:
    return ctx.go404()

  let art = db[].get_last_article(user.get.id, name)
  if art.is_none:
    return ctx.go404()

  resp art.get.to_html()
