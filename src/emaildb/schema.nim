const schema*: seq[string] = @["""
PRAGMA user_version = 2""", """
CREATE TABLE part (
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
          )""", """
CREATE TABLE header_name (
            id        INTEGER PRIMARY KEY NOT NULL,
            name      TEXT NOT NULL,
            CONSTRAINT name_unique UNIQUE (name)
          )""", """
CREATE TABLE header_data (
            id        INTEGER PRIMARY KEY NOT NULL,
            name_id   INTEGER NOT NULL,
            guid      TEXT NOT NULL,
            raw_name  TEXT NOT NULL,
            raw_sep   TEXT NOT NULL,
            raw_value TEXT NOT NULL,
            FOREIGN KEY (name_id) REFERENCES header_name (id),
            CONSTRAINT guid_unique UNIQUE (guid)
          )""", """
CREATE TABLE header (
            id             INTEGER PRIMARY KEY NOT NULL,
            part_id        INTEGER NOT NULL,
            rank           INTEGER NOT NULL,
            header_data_id INTEGER NOT NULL,
            FOREIGN KEY (part_id) REFERENCES part (id),
            FOREIGN KEY (header_data_id) REFERENCES header_data (id),
            CONSTRAINT rank_unique UNIQUE (part_id, rank)
          )""", """
CREATE TABLE email (
            id       INTEGER PRIMARY KEY NOT NULL,
            part_id  INTEGER NOT NULL,
            FOREIGN KEY (part_id) REFERENCES part (id)
          )""", """
CREATE VIEW raw_email AS
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
            GROUP BY id"""]

