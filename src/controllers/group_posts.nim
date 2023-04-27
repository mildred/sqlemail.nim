import std/prelude
import std/strformat
import prologue

import ./groups
import ./errors
import ../db/users
import ../db/articles
import ../db/votes
import ../context
import ../convert_articles

proc create*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  # let current_user = db[].get_user(hash_email(ctx.session.getOrDefault("email", "")))
  let (g, member) = ctx.get_group()

  if g.is_none(): return ctx.go404()
  if member.is_none(): return ctx.go403()

  let html = ctx.getFormParamsOption("html")
  if html.is_none:
    resp "Missing html parameter", Http400
    return
  let parent_patch = ctx.getFormParamsOption("parent_patch")
  if parent_patch.is_none:
    resp "Missing parent_patch parameter", Http400
    return

  var article: Article
  article.set_author(g.get, member.get)
  article.set_group(g.get, member.get)
  article.from_html(html.get)
  article.timestamp = db[].get_julianday()

  article.id = db[].create_article(article, parent_patch.get)

  var vote: Vote
  vote.set_author(g.get, member.get)
  vote.set_article(article)
  vote.vote = 1.0
  vote.guid = vote.compute_hash()
  vote.id = db[].save_new(vote)

  resp "", Http201
