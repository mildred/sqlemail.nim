import std/strformat
import std/parseutils
import prologue

import ../context
import ../db/groups

proc create*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let gi = new(GroupItem)
  gi.seed_userdata = ctx.getFormParamsOption("seed_userdata").get()
  discard ctx.getFormParamsOption("others_members_weight").get().parseFloat(gi.others_members_weight)
  discard ctx.getFormParamsOption("moderation_default_score").get().parseFloat(gi.moderation_default_score)
  # TODO: construct a list of participating pods
  # for each pod, propagate the group item
  gi[].compute_new()
  db[].save_new(gi[])
  resp redirect(&"/@{gi.guid}/")

