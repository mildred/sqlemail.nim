const schema* = @["""
PRAGMA user_version = 2""", """
CREATE TABLE user (
            id         INTEGER PRIMARY KEY NOT NULL,
            local_part TEXT NOT NULL,
            email      TEXT NOT NULL,
            totp_url   TEXT NOT NULL
          )"""]

