import prologue

import ../context

proc index*(ctx: Context) {.async, gcsafe.} =
  resp redirect("/app/")

