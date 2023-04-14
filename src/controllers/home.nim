import prologue

import ../context
import ../db/users
import ../db/groups

import ../views/layout
import ../views/groups as vgroups

proc index*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let current_user = db[].get_user(hash_email(ctx.session.getOrDefault("email", "")))

  let groups = db[].list_groups_with_user(current_user.get().id)

  resp ctx.layout(group_list(groups), title = "Home")

