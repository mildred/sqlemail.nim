import std/strformat

import prologue

import ../views/[layout, errors]

proc go404*(ctx: Context) {.async.} =
  resp ctx.layout(errors.error_page(&"Page Not Found {ctx.request.url}"), title = "Not Found"), Http404

proc go403*(ctx: Context) {.async.} =
  resp ctx.layout(errors.error_page("Forbidden operation"), title = "Forbidden"), Http403
