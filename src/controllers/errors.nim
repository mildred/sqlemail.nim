import prologue

import ../views/[layout, errors]

proc go404*(ctx: Context) {.async.} =
  resp ctx.layout(errors.error404(), title = "Not Found"), Http404
