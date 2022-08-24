import std/strformat
import prologue

import ../views/layout
import ../views/common

proc index*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let user_guid = ctx.getPathParams("userguid", "")
  let user = db[].get_user(user_guid)
  if user_guid == ctx.current_user_guid():
    resp ctx.layout(article_new() & article_index(), title = "User index")
  else:
  resp ctx.layout("", title = "User index")

proc create*(ctx: Context) {.async, gcsafe.} =
  discard

