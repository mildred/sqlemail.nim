import std/strformat
import prologue
import easy_sqlite3

type AppContext* = ref object of Context
  db*: ref Database
  smtp*: string
  sender*: string

proc contextMiddleware*(db_file, smtp, sender: string): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    let ctx = AppContext(ctx)
    ctx.smtp = smtp
    ctx.sender = sender
    if ctx.sender == "":
      ctx.sender = "no-reply@{ctx.request.hostName}"
    if ctx.db == nil:
      ctx.db = new(Database)
      ctx.db[] = init_database(db_file)
    await switch(ctx)
