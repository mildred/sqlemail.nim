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
            local_user_id TEXT NOT NULL,
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
      of 1:
        db.exec("""
          CREATE TABLE IF NOT EXISTS paragraphs (
            id          INTEGER PRIMARY KEY NOT NULL,
            guid        TEXT NOT NULL,
            text        TEXT NOT NULL,
            style       TEXT NOT NULL DEFAULT '',
            CONSTRAINT guid_unique UNIQUE (guid)
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS patches (
            id          INTEGER PRIMARY KEY NOT NULL,
            guid        TEXT NOT NULL,
            parent_id   INTEGER,
            FOREIGN KEY (parent_id) REFERENCES patches (id),
            CONSTRAINT guid_unique UNIQUE (guid)
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS patch_items (
            patch_id     INTEGER NOT NULL,
            paragraph_id INTEGER NOT NULL,
            rank         INTEGER NOT NULL,
            PRIMARY KEY (patch_id, paragraph_id),
            FOREIGN KEY (patch_id) REFERENCES patches (id),
            FOREIGN KEY (paragraph_id) REFERENCES paragraphs (id)
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS subjects (
            id          INTEGER PRIMARY KEY,
            guid        TEXT NOT NULL,
            name        TEXT NOT NULL,
            CONSTRAINT guid_unique UNIQUE (guid)
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS types (
            type        TEXT PRIMARY KEY NOT NULL
          );
        """)
        db.exec("""
          INSERT INTO types (type) VALUES ('subject'), ('article'), ('paragraph');
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS articles (
            id          INTEGER PRIMARY KEY NOT NULL,
            patch_id    INTEGER NOT NULL,
            user_id     INTEGER NOT NULL,
            reply_guid  TEXT NOT NULL,
            reply_type  TEXT NOT NULL,
            reply_index INTEGER DEFAULT 0,
            timestamp   REAL NOT NULL DEFAULT (julianday('now')),
            FOREIGN KEY (reply_type) REFERENCES types (type),
            FOREIGN KEY (patch_id) REFERENCES patches (id),
            FOREIGN KEY (user_id) REFERENCES users (id)
          );
        """)
        user_version = 2
      of 2:
        db.exec("""
          CREATE TABLE IF NOT EXISTS group_items (
            id                       INTEGER PRIMARY KEY NOT NULL,
            guid                     TEXT NOT NULL,
            root_guid                TEXT NOT NULL,
            parent_id                INTEGER DEFAULT NULL,
            parent_guid              TEXT DEFAULT NULL,
            seed_userdata            TEXT NOT NULL DEFAULT '',
            others_members_weight    REAL DEFAULT 0,
            moderation_default_score REAL DEFAULT 0,
            FOREIGN KEY (root_guid) REFERENCES group_items (guid),
            FOREIGN KEY (parent_guid) REFERENCES group_items (guid),
            FOREIGN KEY (parent_id) REFERENCES group_items (id),
            CONSTRAINT guid_unique UNIQUE (guid)
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS group_members (
            id                 INTEGER PRIMARY KEY NOT NULL,
            obsoleted_by       INTEGER DEFAULT NULL,
            group_item_id      INTEGER NOT NULL,
            external           BOOLEAN NOT NULL,
            weight             REAL NOT NULL DEFAULT 1,
            nickname           TEXT,
            pod_url            TEXT,
            local_user_id      TEXT,
            user_id            INTEGER,
            FOREIGN KEY (obsoleted_by) REFERENCES group_members (id),
            FOREIGN KEY (group_item_id) REFERENCES group_items (id),
            FOREIGN KEY (user_id) REFERENCES users (id)
          );
        """)
        user_version = 3
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
