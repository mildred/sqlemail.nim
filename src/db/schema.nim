const schema* = @["""
PRAGMA user_version = 7""", """
CREATE TABLE users (
            id            INTEGER PRIMARY KEY NOT NULL
          )""", """
CREATE TABLE user_emails (
            user_id       INTEGER NOT NULL,
            email_hash    TEXT NOT NULL,
            totp_url      TEXT,
            valid         BOOLEAN DEFAULT FALSE,
            PRIMARY KEY (user_id, email_hash),
            FOREIGN KEY (user_id) REFERENCES users (id),
            CONSTRAINT email_hash_unique UNIQUE (email_hash)
          )""", """
CREATE TABLE paragraphs (
            id          INTEGER PRIMARY KEY NOT NULL,
            guid        TEXT NOT NULL,
            text        TEXT NOT NULL,
            style       TEXT NOT NULL DEFAULT '',
            CONSTRAINT guid_unique UNIQUE (guid)
          )""", """
CREATE TABLE patches (
            id          INTEGER PRIMARY KEY NOT NULL,
            guid        TEXT NOT NULL,
            parent_id   INTEGER,
            FOREIGN KEY (parent_id) REFERENCES patches (id),
            CONSTRAINT guid_unique UNIQUE (guid)
          )""", """
CREATE TABLE patch_items (
            patch_id     INTEGER NOT NULL,
            paragraph_id INTEGER NOT NULL,
            rank         INTEGER NOT NULL,
            PRIMARY KEY (patch_id, paragraph_id),
            FOREIGN KEY (patch_id) REFERENCES patches (id),
            FOREIGN KEY (paragraph_id) REFERENCES paragraphs (id)
          )""", """
CREATE TABLE subjects (
            id          INTEGER PRIMARY KEY,
            guid        TEXT NOT NULL,
            name        TEXT NOT NULL,
            CONSTRAINT guid_unique UNIQUE (guid)
          )""", """
CREATE TABLE types (
            type        TEXT PRIMARY KEY NOT NULL
          )""", """
CREATE TABLE group_member_items (
            id                 INTEGER PRIMARY KEY NOT NULL,
            group_member_id    INTEGER NOT NULL,
            pod_url            TEXT,
            local_user_id      TEXT,
            FOREIGN KEY (group_member_id) REFERENCES group_members (id)
          )""", """
CREATE TABLE group_items (
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
          )""", """
CREATE TABLE group_members (
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
          )""", """
CREATE TABLE votes (
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
          )""", """
CREATE TABLE user_pods (
            id            INTEGER PRIMARY KEY NOT NULL,
            user_id       INTEGER NOT NULL,
            pod_url       TEXT NOT NULL,        -- public pod URL
            local_user_id TEXT NOT NULL,        -- public user id scoped by pod URL
            CONSTRAINT user_id_pod_url_unique UNIQUE (user_id, pod_url),
            FOREIGN KEY (user_id) REFERENCES users (id)
          )""", """
CREATE TABLE articles (
            id                  INTEGER PRIMARY KEY NOT NULL,
            patch_id            INTEGER NOT NULL,
            user_id             INTEGER NOT NULL,

            -- the article it modified
            mod_article_id      INTEGER DEFAULT NULL,
            mod_article_guid    INTEGER DEFAULT NULL,

            -- the item replying to, may be NULL
            reply_guid          TEXT DEFAULT NULL,      -- object guid being replied to (article)
            reply_index         INTEGER DEFAULT NULL,   -- paragraph replied to within article

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

            timestamp           REAL NOT NULL DEFAULT (julianday('now')),

            FOREIGN KEY (mod_article_id) REFERENCES articles (id),
            FOREIGN KEY (mod_article_guid) REFERENCES articles (guid),
            FOREIGN KEY (patch_id) REFERENCES patches (id),
            FOREIGN KEY (user_id) REFERENCES users (id),
            FOREIGN KEY (author_group_id) REFERENCES group_items (id),
            FOREIGN KEY (author_group_guid) REFERENCES group_items (guid),
            FOREIGN KEY (group_id) REFERENCES group_items (id),
            FOREIGN KEY (group_guid) REFERENCES group_items (guid)
          )"""]

