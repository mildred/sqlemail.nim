import std/strformat
import std/strutils
import std/parseutils
import prologue

import ../context
import ../db/users
import ../db/groups
import ../views/layout
import ../views/groups as vgroups

proc create*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let gi = new(GroupItem)
  let preset = ctx.getFormParamsOption("_preset").get("")
  gi.name = ctx.getFormParamsOption("name").get("")
  gi.seed_userdata = ctx.getFormParamsOption("seed_userdata").get("")
  discard ctx.getFormParamsOption("others_members_weight").get("0").parseFloat(gi.others_members_weight)
  discard ctx.getFormParamsOption("group_type").get("0").parseInt(gi.group_type)
  discard ctx.getFormParamsOption("moderation_default_score").get("0").parseFloat(gi.moderation_default_score)
  # TODO: construct a list of participating pods
  # for each pod, propagate the group item

  # In any case add self to group
  let current_user = db[].get_user(hash_email(ctx.session.getOrDefault("email", "")))
  var m: GroupMember
  m.local_id = 1
  discard ctx.getFormParamsOption("self_weight").get("1").parseFloat(m.weight)
  m.nickname = ctx.getFormParamsOption("self_nickname").get(gi[].name)
  m.user_id = current_user.get.id
  for p in current_user.get.pods:
    var i: GroupMemberItem
    i.pod_url = p.pod_url
    i.local_user_id = p.local_user_id
    m.items.add(i)
  gi[].members.add(m)

  if preset == "identity":
    gi[].group_type = 0
    gi[].compute_new()
    db[].save_new(gi[])

    gi[].group_type = 1
    gi[].compute_new()
    db[].save_new(gi[])

    gi[].group_type = 3
    gi[].compute_new()
    db[].save_new(gi[])

    resp redirect(&"/", code = Http303)

  else:
    gi[].compute_new()
    db[].save_new(gi[])
    resp redirect(&"/@{gi.guid}/", code = Http303)

proc show*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let group_guid = ctx.getPathParams("groupguid", "")

  let g = db[].get_group(group_guid)
  if g.is_none():
    resp ctx.layout("Not Found", title = &"Group {group_guid}"), code = Http404
    return

  let gi = g.get()
  resp ctx.layout(group_show(gi), title = &"Group {gi.name}")
