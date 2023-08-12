import std/strutils
import strformat
import easy_sqlite3

import ./schema

type MigrationDefect* = object of Defect

proc get_user_version*(): tuple[value: int] {.importdb: "PRAGMA user_version".}
proc set_user_version*(db: var Database, v: int) =
  discard db.exec(&"PRAGMA user_version = {$v}")

iterator table_schema_sql(): tuple[sql: string] {.importdb: "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL".} = discard

proc get_schema(db: var Database): seq[string] =
  var user_version = db.get_user_version().value
  result = @[]
  result.add(&"PRAGMA user_version = {$user_version}")
  for row in db.table_schema_sql():
    result.add(row.sql)

proc migrate*(db: var Database): bool =
  var user_version = db.get_user_version().value
  if user_version == 0:
    echo "Initialise database..."
  var migrating = true
  while migrating:
    db.transaction:
      var description: string
      let old_version = user_version
      case user_version
      of 0:
        db.set_user_version(1)
        for sql in schema.schema:
          db.exec(sql)
        user_version = db.get_user_version().value
      of 1:
        description = "create user table"
        db.exec("""
          CREATE TABLE IF NOT EXISTS user (
            id         INTEGER PRIMARY KEY NOT NULL,
            local_part TEXT NOT NULL,
            email      TEXT NOT NULL,
            totp_url   TEXT NOT NULL
          );
        """)
        user_version = 2
      else:
        migrating = false
      if migrating:
        if old_version == user_version:
          echo &"Failed migration at v{user_version}"
          return false
        db.set_user_version(user_version)
        if description == "":
          echo &"Migrated database v{old_version} to v{user_version}"
        else:
          echo &"Migrated database v{old_version} to v{user_version}: {description}"
  echo "Finished database initialization"

  let actual_schema = db.get_schema()
  if schema.schema != actual_schema:
    echo "WARNING: Schema not up to date in code. Please replace with:"
    var schema_strings: seq[string] = @[]
    for str in actual_schema:
      schema_strings.add(&"\"\"\"\n{str}\"\"\"")
    let schema_str: string = schema_strings.join(", ")
    echo &"const schema* = @[{schema_str}]"
    return false

  return true

proc open_database*(filename: string): Database =
  echo &"Open database {filename}"
  result = initDatabase(filename)
  if not result.migrate():
    raise newException(MigrationDefect, "Failed to migrate database")
