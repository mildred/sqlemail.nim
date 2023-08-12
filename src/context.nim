import std/strformat
import prologue
import easy_sqlite3

import ./db/migration
import ./litefs

export litefs.primary

type AppContext* = ref object of Context
  db*: ref Database
  db_file: string
  smtp_host*: string
  smtp_port*: Port
  sender*: string
  assets_dir*: string
  secretkey*: string
  dbdir*: string
  dbprefix*: string
  litefs*: LiteFS

proc contextMiddleware*(db_file, assets_dir, smtp_host: string, smtp_port: Port, sender, secretkey, dbdir, dbprefix: string): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    let ctx = AppContext(ctx)
    ctx.db_file = db_file
    ctx.secretkey = secretkey
    ctx.assets_dir = assets_dir
    ctx.smtp_host = smtp_host
    ctx.smtp_port = smtp_port
    ctx.sender = sender
    ctx.dbdir = dbdir
    ctx.litefs = newLiteFS(dbdir)
    ctx.dbprefix = dbprefix
    if ctx.sender == "":
      ctx.sender = "no-reply@{ctx.request.hostName}"
    if ctx.db == nil:
      ctx.db = new(Database)
      ctx.db[] = init_database(db_file)
    await switch(ctx)

proc db_txid*(ctx: AppContext): uint64 =
  ctx.litefs.txid(ctx.db_file)

