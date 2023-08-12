import std/options
import std/json
import std/strutils
import std/strformat
import easy_sqlite3
import emailparser

import ./guid

proc insert_part*(guid: string, parent_id: Option[int], rank: int, delimiter: Option[string], crlf: string, raw: string): tuple[id: int] {.importdb: """
  INSERT INTO part (guid, parent_id, rank, delimiter, crlf, raw)
  VALUES ($guid, $parent_id, $rank, $delimiter, $crlf, $raw)
  ON CONFLICT(guid) DO UPDATE SET id = id
  RETURNING id
""".}

proc insert_header_name*(name: string): tuple[id: int] {.importdb: """
  INSERT INTO header_name (name)
  VALUES (LOWER($name))
  ON CONFLICT(name) DO UPDATE SET id = id
  RETURNING id
""".}

proc insert_header_data*(name_id: int, guid: string, raw_name: string, raw_sep: string, raw_value: string): tuple[id: int] {.importdb: """
  INSERT INTO header_data (name_id, guid, raw_name, raw_sep, raw_value)
  VALUES ($name_id, $guid, $raw_name, $raw_sep, $raw_value)
  ON CONFLICT(guid) DO UPDATE SET id = id
  RETURNING id
""".}

proc insert_header*(part_id: int, rank: int, header_data_id: int): tuple[id: int] {.importdb: """
  INSERT INTO header (part_id, rank, header_data_id)
  VALUES ($part_id, $rank, $header_data_id)
  ON CONFLICT(part_id, rank) DO UPDATE SET id = id
  RETURNING id
""".}

proc insert_email*(part_id: int): tuple[id: int] {.importdb: """
  INSERT INTO email (part_id)
  VALUES ($part_id)
  RETURNING id
""".}

proc get_raw_email*(id: int): tuple[id: int, raw: string, guid: string] {.importdb: """
  SELECT r.id, r.raw, p.guid
  FROM raw_email r JOIN email e on r.id = e.id JOIN part p ON p.id = e.part_id
  WHERE r.id = $id
""".}

proc compute_hash*(part: Part, parent_id: Option[int], order: int = 0): string {.gcsafe.} =
  var prefix: string = ""
  if parent_id.is_some():
    prefix = $parent_id.get
  result = compute_hash(&"{prefix}-{$order}-{part.to_email}")

proc insert_part_recursive(db: var Database, part: Part, parent: Option[int] = none(int), parent_order: ptr int = nil): int =
  var parent_order_val: int = 0
  if parent_order != nil:
    parent_order_val = parent_order[]

  var boundary: Option[string]
  if part.boundary == "":
    boundary = none(string)
    assert parent.is_none
  else:
    boundary = some(part.boundary)
    assert parent.is_some

  var order: int = 1
  var part_id = db.insert_part(part.compute_hash(parent, parent_order_val), parent, parent_order_val, boundary, part.crlf, part.body).id
  result = part_id
  for header in part.headers:
    let parsed = parse_header(header)
    let name_id = db.insert_header_name(parsed.name).id
    let data_id = db.insert_header_data(name_id, compute_hash(header), parsed.name, parsed.sep, parsed.raw_value).id
    discard db.insert_header(part_id, order, data_id).id
    order += 1

  order = 1
  var order_ptr = parent_order
  if order_ptr == nil:
    order_ptr = addr order

  for sub_part in part.sub_parts:
    discard db.insert_part_recursive(sub_part, some(part_id), order_ptr)
    order_ptr[] += 1

proc insert_email*(db: var Database, part: Part): int =
  db.transaction:
    let part_id = db.insert_part_recursive(part)
    result = db.insert_email(part_id).id
