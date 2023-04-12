import std/md5
import std/strutils
import std/os
import std/mimetypes
import prologue

import ../context
import ../assets
import ./errors

proc get*(ctx: Context) {.async, gcsafe.} =
  let assets_dir = AppContext(ctx).assets_dir
  let path = ctx.getPathParams("path", "").replace("../", "")
  let file_path = assets_dir / path
  if fileExists(file_path):
    await ctx.staticFileResponse(path, assets_dir)
  else:
    let content = getAsset(file_path)
    if content.isNone():
      return ctx.go404()

    let etag = get_md5(content.get())

    var ext = path.splitFile.ext
    if ext.len > 0:
      ext = ext[1 .. ^1]
    let mimetype = ctx.gScope.ctxSettings.mimeDB.getMimetype(ext)

    ctx.response.setHeader("Etag", etag)
    if mimetype.len != 0:
      ctx.response.setHeader("Content-Type", mimetype & "; charset=utf-8")

    if ctx.request.hasHeader("If-None-Match") and ctx.request.headers["If-None-Match"] == etag:
      await ctx.respond(Http304, "")

    ctx.response.body = content.get()
    await ctx.respond()

