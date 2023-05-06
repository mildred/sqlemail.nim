import std/strformat
import prologue
import easy_sqlite3

import ./db/users

export hash_email

proc current_user_guid*(ctx: Context): string =
  hash_email(ctx.session["email"])

type AppContext* = ref object of Context
  db*: ref Database
  smtp*: string
  sender*: string
  assets_dir*: string
  secretkey*: string

proc contextMiddleware*(db_file, assets_dir, smtp, sender, secretkey: string): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    let ctx = AppContext(ctx)
    ctx.secretkey = secretkey
    ctx.assets_dir = assets_dir
    ctx.smtp = smtp
    ctx.sender = sender
    if ctx.sender == "":
      ctx.sender = "no-reply@{ctx.request.hostName}"
    if ctx.db == nil:
      ctx.db = new(Database)
      ctx.db[] = init_database(db_file)
    await switch(ctx)
