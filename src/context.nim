import prologue
import easy_sqlite3

type AppContext* = ref object of Context
  db*: ref Database

proc contextMiddleware*(db_file: string): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    let ctx = AppContext(ctx)
    if ctx.db == nil:
      ctx.db = new(Database)
      ctx.db[] = init_database(db_file)
    await switch(ctx)
