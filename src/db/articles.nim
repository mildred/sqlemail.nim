import std/options
import std/strutils
import easy_sqlite3
import libp2p/multihash

type
  Paragraph* = tuple
    id: int
    guid: string
    style: string
    text: string

  Patch* = tuple
    id:          int
    parent_id:   int
    guid:        string
    parent_guid: string
    timestamp:   float
    paragraphs:  seq[Paragraph]

  Article* = tuple
    id: int
    patch_id: int
    patch_guid: string
    user_id: int
    name: string
    timestamp: float
    paragraphs: seq[Paragraph]

proc last_article(user_id: int, name: string): Option[tuple[id: int, patch_id: int, patch_guid: string, user_id: int, name: string, timestamp: float]] {.importdb: """
  SELECT   a.id, a.patch_id, p.guid, a.user_id, a.name, a.timestamp
  FROM     articles a JOIN patches p ON a.patch_id = p.id
  WHERE    a.user_id = $user_id AND a.name = $name
  ORDER BY a.timestamp DESC
  LIMIT    1
""" .}

iterator paragraphs(patch_id: int): tuple[id: int, guid: string, style: string, text: string] {.importdb: """
  SELECT   p.id, p.guid, p.style, p.text
  FROM     patch_items pi JOIN paragraphs p ON pi.paragraph_id = p.id
  WHERE    pi.patch_id = $patch_id
  ORDER BY pi.rank ASC
""".} = discard

proc get_last_article*(db: var Database, user_id: int, name: string): Option[Article] =
  let art = db.last_article(user_id, name)
  if art.is_none:
    return none(Article)

  var res: Article
  res.id = art.get.id
  res.patch_id = art.get.patch_id
  res.patch_guid = art.get.patch_guid
  res.user_id = art.get.user_id
  res.name = art.get.name
  res.timestamp = art.get.timestamp

  for p in db.paragraphs(res.patch_id):
    res.paragraphs.add(p)

  result = some(res)

proc get_julianday(): tuple[time: float] {.importdb: "SELECT julianday('now')".}

proc insert_paragraph(guid, style, text: string) {.importdb: """
  INSERT INTO paragraphs (guid, style, text)
  VALUES ($guid, $style, $text)
  ON CONFLICT DO NOTHING
""".}

proc get_patch_id(guid: string): Option[tuple[id: int]] {.importdb: """
  SELECT id FROM patches WHERE guid = $guid
""".}

proc insert_patch(guid, parent_guid: string, timestamp: float): tuple[id: int] {.importdb: """
  INSERT INTO patches (guid, parent_id, timestamp)
  SELECT $guid, (SELECT id FROM patches WHERE guid = $parent_guid), $timestamp
  RETURNING id
""".}

proc insert_patch_item(patch_guid, paragraph_guid: string, rank: int) {.importdb: """
  INSERT INTO patch_items (patch_id, paragraph_id, rank)
  SELECT (SELECT id FROM patches WHERE guid = $patch_guid),
         (SELECT id FROM paragraphs WHERE guid = $paragraph_guid),
         $rank
""".}

proc insert_article(patch_guid: string, user_id: int, name: string, timestamp: float): tuple[id: int] {.importdb: """
  INSERT INTO articles (patch_id, user_id, name, timestamp)
  SELECT (SELECT id FROM patches WHERE guid = $patch_guid),
         $user_id, $name, $timestamp
  RETURNING id
""".}

proc compute_hash*(input: seq[string]): string =
  var source: seq[string]
  for item in input:
    source.add([$item.len, " ", item])
  result = $MultiHash.digest("sha2-256", cast[seq[byte]](source.join(""))).get()

proc compute_hash*(paragraph: Paragraph): string =
  var source: seq[string]
  source.add(paragraph.style)
  source.add(paragraph.text)
  result = compute_hash(source)

proc compute_hash*(patch: Patch, force_compute: bool = false): string =
  var source: seq[string]
  source.add(patch.parent_guid)
  source.add($patch.timestamp)
  source.add($patch.paragraphs.len)
  for p in patch.paragraphs:
    if not force_compute and p.guid != "":
      source.add(p.guid)
    else:
      source.add(p.compute_hash())
  result = compute_hash(source)

proc create_article*(db: var Database, art: Article, parent_patch_id: string) =
  let timestamp = db.get_julianday().time
  var pat: Patch
  pat.parent_guid = parent_patch_id
  pat.timestamp   = timestamp
  pat.paragraphs  = art.paragraphs
  var i = 0
  while i < pat.paragraphs.len:
    pat.paragraphs[i].guid = pat.paragraphs[i].compute_hash()
    i = i + 1
  pat.guid = pat.compute_hash()
  discard db.insert_patch(pat.guid, pat.parent_guid, pat.timestamp)
  var rank = 1
  for p in pat.paragraphs:
    db.insert_paragraph(p.guid, p.style, p.text)
    db.insert_patch_item(pat.guid, p.guid, rank)
    rank = rank + 1
  discard db.insert_article(pat.guid, art.user_id, art.name, pat.timestamp)

