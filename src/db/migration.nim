import strformat
import easy_sqlite3

type MigrationDefect* = object of Defect

proc get_user_version*(): tuple[value: int] {.importdb: "PRAGMA user_version".}
proc set_user_version*(db: var Database, v: int) =
  discard db.exec(&"PRAGMA user_version = {$v}")

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
        description = "database initialized"
        db.exec("""
          CREATE TABLE IF NOT EXISTS users (
            id            INTEGER PRIMARY KEY NOT NULL
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS user_pods (
            user_id       INTEGER NOT NULL,
            pod_url       TEXT NOT NULL,
            PRIMARY KEY (user_id, pod_url),
            FOREIGN KEY (user_id) REFERENCES users (id)
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS user_emails (
            user_id       INTEGER NOT NULL,
            email_hash    TEXT NOT NULL,
            totp_url      TEXT,
            valid         BOOLEAN DEFAULT FALSE,
            PRIMARY KEY (user_id, email_hash),
            FOREIGN KEY (user_id) REFERENCES users (id),
            CONSTRAINT email_hash_unique UNIQUE (email_hash)
          );
        """)
        user_version = 1
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
  return true

proc open_database*(filename: string): Database =
  echo &"Open database {filename}"
  result = initDatabase(filename)
  if not result.migrate():
    raise newException(MigrationDefect, "Failed to migrate database")
