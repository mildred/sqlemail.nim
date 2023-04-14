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
        description = "database initialized"
        db.exec("""
          CREATE TABLE IF NOT EXISTS users (
            id            INTEGER PRIMARY KEY NOT NULL
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS user_pods (
            id            INTEGER PRIMARY KEY NOT NULL,
            user_id       INTEGER NOT NULL,
            pod_url       TEXT NOT NULL,        -- public pod URL
            local_user_id TEXT NOT NULL,        -- public user id scoped by pod URL
            CONSTRAINT user_id_pod_url_unique UNIQUE (user_id, pod_url),
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
        user_version = 2
      of 2:
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
        user_version = 3
      of 3:
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
            nickname           TEXT,
            weight             REAL NOT NULL DEFAULT 1,
            pod_url            TEXT,
            local_user_id      TEXT,
            user_id            INTEGER,
            FOREIGN KEY (obsoleted_by) REFERENCES group_members (id),
            FOREIGN KEY (group_item_id) REFERENCES group_items (id),
            FOREIGN KEY (user_id) REFERENCES users (id)
          );
        """)
        user_version = 4
      of 4:
        db.exec("DROP TABLE articles")
        db.exec("""
          CREATE TABLE IF NOT EXISTS articles (
            id                  INTEGER PRIMARY KEY NOT NULL,
            patch_id            INTEGER NOT NULL,
            user_id             INTEGER NOT NULL,

            -- the item replying to, may be NULL
            reply_guid          TEXT NOT NULL,          -- object guid being replied to
            reply_type          TEXT NOT NULL,          -- object type (types)
            reply_index         INTEGER DEFAULT 0,      -- unsure: paragraph replied to

            -- author of the message
            -- the message is not published here, the group is only used to keep track of the author
            author_group_id     INTEGER NOT NULL,       -- author personal group
            author_group_guid   TEXT NOT NULL,
            author_member_id    INTEGER,                -- member local_id (optional)

            -- group the article belongs to (can be same as author_group)
            -- where the message is published. If the group is public (others readable) the reply is readable to anyone who has access to the original item
            group_id            INTEGER NOT NULL,
            group_guid          TEXT NOT NULL,
            group_member_id     INTEGER,                -- local_id of member (NULL if other)

            initial_score       REAL NOT NULL DEFAULT 1.0,
            timestamp           REAL NOT NULL DEFAULT (julianday('now')),

            FOREIGN KEY (reply_type) REFERENCES types (type),
            FOREIGN KEY (patch_id) REFERENCES patches (id),
            FOREIGN KEY (user_id) REFERENCES users (id),
            FOREIGN KEY (author_group_id) REFERENCES group_items (id),
            FOREIGN KEY (author_group_guid) REFERENCES group_items (guid),
            FOREIGN KEY (group_id) REFERENCES group_items (id),
            FOREIGN KEY (group_guid) REFERENCES group_items (guid)
          );
        """)
        db.exec("DROP TABLE group_items")
        db.exec("""
          CREATE TABLE IF NOT EXISTS group_items (
            id                       INTEGER PRIMARY KEY NOT NULL,
            guid                     TEXT NOT NULL,
            root_guid                TEXT NOT NULL,             -- group root item
            parent_id                INTEGER DEFAULT NULL,      -- group parent item
            parent_guid              TEXT DEFAULT NULL,
            child_id                 INTEGER DEFAULT NULL,      -- child group item (if any)
            name                     TEXT NOT NULL,             -- group name
            seed_userdata            TEXT NOT NULL DEFAULT '',  -- seed for unique guid
            others_members_weight    REAL DEFAULT 0,            -- weight of unlisted members
            group_type               INTEGER NOT NULL,
                        -- 0: private, only listed members can read
                        -- 1: private, anyone can be invited with link
                        -- 3: public, anyone can read and group is discoverable
            moderation_default_score REAL DEFAULT 0,            -- score for unlisted member's articles

            FOREIGN KEY (root_guid) REFERENCES group_items (guid),
            FOREIGN KEY (parent_guid) REFERENCES group_items (guid),
            FOREIGN KEY (parent_id) REFERENCES group_items (id),
            CONSTRAINT guid_unique UNIQUE (guid)
          );
        """)
        db.exec("DROP TABLE group_members")
        db.exec("""
          CREATE TABLE IF NOT EXISTS group_members (
            id                 INTEGER PRIMARY KEY NOT NULL,
            local_id           INTEGER NOT NULL,        -- unique id within the group
            obsolete           BOOLEAN DEFAULT FALSE,   -- is the member obsolete (private data to pod)
            obsoleted_by       INTEGER DEFAULT NULL,    -- id that makes it obsolete (NULL: removed member)
            group_item_id      INTEGER NOT NULL,        -- group the member belongs to
            nickname           TEXT,                    -- member nickname
            weight             REAL NOT NULL DEFAULT 1, -- member weight within group
            user_id            INTEGER,                 -- user id for instance

            CONSTRAINT local_id_unique UNIQUE (local_id, group_item_id),
            FOREIGN KEY (obsoleted_by) REFERENCES group_members (id),
            FOREIGN KEY (group_item_id) REFERENCES group_items (id),
            FOREIGN KEY (user_id) REFERENCES users (id)
          );
        """)
        db.exec("DROP TABLE user_pods")
        db.exec("""
          CREATE TABLE user_pods (
            id            INTEGER PRIMARY KEY NOT NULL,
            user_id       INTEGER NOT NULL,
            pod_url       TEXT NOT NULL,        -- public pod URL
            local_user_id TEXT NOT NULL,        -- public user id scoped by pod URL
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS group_member_items (
            id                  INTEGER PRIMARY KEY NOT NULL,
            group_member_id     INTEGER NOT NULL,
            user_pod_id         INTEGER,
            pod_url             TEXT,
            local_user_id       TEXT,
            FOREIGN KEY (group_member_id) REFERENCES group_members (id),
            FOREIGN KEY (user_pod_id) REFERENCES user_pods (id)
          )
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS moderations (
            id                          INTEGER PRIMARY KEY NOT NULL,
            group_id                    INTEGER NOT NULL,
            member_id                   INTEGER NOT NULL,
            article_id                  INTEGER NOT NULL,
            group_guid                  TEXT NOT NULL,
            member_pod_url              TEXT NOT NULL,
            member_local_user_id        TEXT NOT NULL,
            article_guid                TEXT NOT NULL,
            score                       REAL NOT NULL,
            FOREIGN KEY (group_id) REFERENCES group_items (id),
            FOREIGN KEY (member_id) REFERENCES group_members (id),
            FOREIGN KEY (article_id) REFERENCES articles (id),
            FOREIGN KEY (group_guid) REFERENCES group_items (guid),
            FOREIGN KEY (article_guid) REFERENCES articles (guid)
          );
        """)
        user_version = 5
      of 5:
        db.exec("""
          CREATE TABLE IF NOT EXISTS votes (
            id                      INTEGER PRIMARY KEY NOT NULL,
            guid                    TEXT NOT NULL,
            group_id                INTEGER NOT NULL,
            group_guid              TEXT NOT NULL,
            member_local_user_id    INTEGER NOT NULL,
            article_id              INTEGER NOT NULL,
            article_guid            TEXT NOT NULL,
            paragraph_rank          INTEGER,
            vote                    REAL NOT NULL,
            CONSTRAINT guid_unique UNIQUE (guid)
            FOREIGN KEY (group_id, group_guid) REFERENCES groups (id, guid),
            FOREIGN KEY (article_id, article_guid) REFERENCES articles (id, guid)
          );
        """)
        user_version = 6
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
