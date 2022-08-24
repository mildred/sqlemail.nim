import std/strformat
import prologue

import ../views/layout
import ../views/common
import ../views/groups

proc index*(ctx: Context) {.async, gcsafe.} =
  resp ctx.layout(group_new(), title = "Home")

