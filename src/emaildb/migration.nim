import std/strutils
import std/os
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

proc migrate*(db: var Database, filename: string): bool =
  var user_version = db.get_user_version().value
  if user_version == 0:
    echo &"[{filename}] Initialise database..."
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
        description = "database initialized"
        db.exec("""
          CREATE TABLE IF NOT EXISTS part (
            id        INTEGER PRIMARY KEY NOT NULL,
            guid      TEXT,
            parent_id INTEGER,
                      -- references the parent body part if this is a part from
                      -- multipart. NULL if there is no parent (whole body)
            rank      INTEGER NOT NULL DEFAULT 0,
                      -- part order within parent. There is always an epilogue
                      -- part that contains the last delimiter even if the
                      -- epilogue itself is empty.
            delimiter TEXT,
                      -- The delimiter introducing the part or final delimiter
                      -- for the epilogue. NULL if there is no parent.
            crlf      TEXT NOT NULL, -- CRLF between headers and body
            raw       TEXT NOT NULL,
                      -- contains the part body or the multipart prologue
            FOREIGN KEY (parent_id) REFERENCES part (id),
            CONSTRAINT delimiter_exists CHECK ((parent_id IS NULL AND delimiter IS NULL) OR (parent_id IS NOT NULL AND delimiter IS NOT NULL)),
            CONSTRAINT guid_unique UNIQUE (guid)
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS header_name (
            id        INTEGER PRIMARY KEY NOT NULL,
            name      TEXT NOT NULL,
            CONSTRAINT name_unique UNIQUE (name)
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS header_data (
            id        INTEGER PRIMARY KEY NOT NULL,
            name_id   INTEGER NOT NULL,
            guid      TEXT NOT NULL,
            raw_name  TEXT NOT NULL,
            raw_sep   TEXT NOT NULL,
            raw_value TEXT NOT NULL,
            FOREIGN KEY (name_id) REFERENCES header_name (id),
            CONSTRAINT guid_unique UNIQUE (guid)
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS header (
            id             INTEGER PRIMARY KEY NOT NULL,
            part_id        INTEGER NOT NULL,
            rank           INTEGER NOT NULL,
            header_data_id INTEGER NOT NULL,
            FOREIGN KEY (part_id) REFERENCES part (id),
            FOREIGN KEY (header_data_id) REFERENCES header_data (id),
            CONSTRAINT rank_unique UNIQUE (part_id, rank)
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS email (
            id       INTEGER PRIMARY KEY NOT NULL,
            part_id  INTEGER NOT NULL,
            FOREIGN KEY (part_id) REFERENCES part (id)
          );
        """)
        db.exec("""
          CREATE VIEW IF NOT EXISTS raw_email AS
            WITH RECURSIVE
            aggregated_part (id, part_id, prologue, rank, raw) AS (
                SELECT
                  email.id, part.id AS part_id,
                  part.crlf || part.raw AS prologue,
                  '' AS raw,
                  '' AS rank
                FROM email
                JOIN part ON email.part_id = part.id
              UNION ALL
                SELECT
                  ap.id, NULL AS part_id, '' AS prologue,
                  ap.rank || '0H' || printf('%10d', h.rank) AS rank,
                  hd.raw_name || hd.raw_sep || hd.raw_value AS raw
                FROM aggregated_part ap
                JOIN header h ON h.part_id = ap.part_id
                JOIN header_data hd ON h.header_data_id = hd.id
              UNION ALL
                SELECT
                  ap.id, NULL AS part_id, '' AS prologue,
                  ap.rank || '1BODY' AS rank,
                  ap.prologue AS raw
                FROM aggregated_part ap
                WHERE ap.part_id IS NOT NULL
              UNION ALL
                SELECT
                  ap.id, p.id AS part_id,
                  p.crlf || p.raw AS prologue,
                  ap.rank || '2P' || printf('%10d', p.rank) || ' ' AS rank,
                  p.delimiter AS raw
                FROM aggregated_part ap
                JOIN part p ON p.parent_id = ap.part_id
            )
            SELECT id, group_concat(raw, '') AS raw
            FROM (
              SELECT id, rank, raw FROM aggregated_part
              ORDER BY rank ASC
            ) AS ap
            GROUP BY id;
        """)
        user_version = 2
      else:
        migrating = false
      if migrating:
        if old_version == user_version:
          echo &"[{filename}] Failed migration at v{user_version}"
          return false
        db.set_user_version(user_version)
        if description == "":
          echo &"[{filename}] Migrated database v{old_version} to v{user_version}"
        else:
          echo &"[{filename}] Migrated database v{old_version} to v{user_version}: {description}"
  echo &"[{filename}] Finished database initialization"

  let actual_schema = db.get_schema()
  if schema.schema != actual_schema:
    echo &"[{filename}] WARNING: Schema not up to date in code. Please replace with:"
    var schema_strings: seq[string] = @[]
    for str in actual_schema:
      schema_strings.add(&"\"\"\"\n{str}\"\"\"")
    let schema_str: string = schema_strings.join(", ")
    echo &"const schema*: seq[string] = @[{schema_str}]"
    return false

  return true

proc open_database*(filename: string): Database =
  echo &"Open database {filename}"
  result = initDatabase(filename)
  if not result.migrate(filename):
    raise newException(MigrationDefect, "Failed to migrate database")

proc user_database_name*(dbdir: string, dbprefix: string, username: string): string =
  &"{dbdir}/{dbprefix}{username}.db"

proc open_user_database*(dbdir: string, dbprefix: string, username: string): Database =
  create_dir(dbdir)
  open_database(user_database_name(dbdir, dbprefix, username))
