import std/options
import std/json
import std/strutils
import easy_sqlite3

import ./guid
import ./groups

type
  Subject* = tuple
    name: string

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
    paragraphs:  seq[Paragraph]

  Article* = tuple
    id: int
    guid: string
    patch_id: int
    patch_guid: string
    user_id: int
    subject_name: string
    reply_guid: string
    reply_index: Option[int]
    author_group_id: int
    author_group_guid: string
    author_member_id: int
    author_group: ref GroupItem
    author_member: ref GroupMember
    group_id: int
    group_guid: string
    group_member_id: int
    group: ref GroupItem
    group_member: ref GroupMember
    mod_article_guid: Option[string]
    timestamp: float
    paragraphs: seq[Paragraph]
    score: float

proc set_author*(article: var Article, group: GroupItem, member: GroupMember) =
  new(article.author_group)
  new(article.author_member)
  article.user_id = member.user_id
  article.author_group[] = group
  article.author_group_id = group.id
  article.author_group_guid = group.guid
  article.author_member[] = member
  article.author_member_id = member.local_id

proc set_group*(article: var Article, group: GroupItem, member: GroupMember) =
  new(article.group)
  new(article.group_member)
  article.group[] = group
  article.group_id = group.id
  article.group_guid = group.guid
  article.group_member[] = member
  article.group_member_id = member.local_id

proc last_article(user_id: int, name: string): Option[tuple[id: int, patch_id: int, patch_guid: string, user_id: int, name: string, reply_guid: string, reply_index: Option[int], author_group_id: int, author_group_guid: string, author_member_id: int, group_id: int, group_guid: string, group_member_id: int, timestamp: float]] {.importdb: """
  SELECT   a.id, a.patch_id, p.guid, a.user_id, s.name, a.reply_guid, a.reply_index, a.author_group_id, a.author_group_guid, a.author_member_id, a.group_id, a.group_guid, a.group_member_id, a.timestamp
  FROM     articles a
           JOIN patches p ON a.patch_id = p.id
           JOIN subjects s ON a.reply_guid = s.guid
  WHERE    a.user_id = $user_id AND s.name = $name
  ORDER BY a.timestamp DESC
  LIMIT    1
""" .}

iterator articles_for_group(group_id: int): tuple[
  id: int, guid: string, patch_id: int, patch_guid: string,
  user_id: Option[int],
  reply_guid: Option[string], reply_index: Option[int],
  author_group_id: int, author_group_guid: string, author_member_id: int,
  group_id: int, group_guid: string, group_member_id: int,
  timestamp: float, score: float
] {.importdb: """
  SELECT
    a.id, a.guid, a.patch_id, a.patch_guid,
    a.user_id,
    a.reply_guid, a.reply_index,
    a.author_group_id, a.author_group_guid, a.author_member_id,
    a.group_id, a.group_guid, a.group_member_id,
    a.timestamp,
    ( g.moderation_default_score +
      SUM( MIN(MAX(v.vote, -1), 1) * MAX(m.weight, 0) )
    ) AS score
  FROM
    articles a
    JOIN votes v ON v.article_id = a.id
    JOIN group_items g ON v.group_id = g.id
    JOIN group_members m ON m.group_item_id = g.id AND v.member_local_user_id = m.local_id
  WHERE
    g.id = $group_id
  GROUP BY
    a.id, a.guid, a.patch_id, a.patch_guid,
    a.user_id,
    a.reply_guid, a.reply_index,
    a.author_group_id, a.author_group_guid, a.author_member_id,
    a.group_id, a.group_guid, a.group_member_id,
    a.timestamp
  ORDER BY
    a.timestamp ASC
""".} = discard

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
  res.subject_name = art.get.name
  res.reply_guid = art.get.reply_guid
  res.reply_index = art.get.reply_index
  res.author_group_id = art.get.author_group_id
  res.author_group_guid = art.get.author_group_guid
  res.author_member_id = art.get.author_member_id
  res.group_id = art.get.group_id
  res.group_guid = art.get.group_guid
  res.group_member_id = art.get.group_member_id
  res.timestamp = art.get.timestamp

  for p in db.paragraphs(res.patch_id):
    res.paragraphs.add(p)

  result = some(res)

proc get_julianday_sql(): tuple[time: float] {.importdb: "SELECT julianday('now')".}

proc get_julianday*(db: var Database): float =
  let julianday = db.get_julianday_sql()
  return julianday.time

proc insert_subject(guid, name: string) {.importdb: """
  INSERT INTO subjects (guid, name)
  VALUES ($guid, $name)
  ON CONFLICT DO NOTHING
""".}

proc insert_paragraph(guid, style, text: string) {.importdb: """
  INSERT INTO paragraphs (guid, style, text)
  VALUES ($guid, $style, $text)
  ON CONFLICT DO NOTHING
""".}

proc get_patch_id(guid: string): Option[tuple[id: int]] {.importdb: """
  SELECT id FROM patches WHERE guid = $guid
""".}

proc insert_patch(guid, parent_guid: string): tuple[id: int] {.importdb: """
  INSERT INTO patches (guid, parent_id)
  SELECT $guid, (SELECT id FROM patches WHERE guid = $parent_guid)
  ON CONFLICT (guid) DO NOTHING
  RETURNING id
""".}

proc insert_patch_item(patch_guid, paragraph_guid: string, rank: int) {.importdb: """
  INSERT INTO patch_items (patch_id, paragraph_id, rank)
  SELECT (SELECT id FROM patches WHERE guid = $patch_guid),
         (SELECT id FROM paragraphs WHERE guid = $paragraph_guid),
         $rank
""".}

proc insert_article(
  guid: string, patch_guid: string, user_id: int, subject_guid: Option[string],
  author_group_id: int, author_group_guid: string, author_member_id: int,
  group_id: int, group_guid: string, group_member_id: int
): tuple[id: int] {.importdb: """
  INSERT INTO articles (
    guid, patch_id, patch_guid, user_id, reply_guid, reply_index, author_group_id,
    author_group_guid, author_member_id, group_id, group_guid, group_member_id,
    timestamp)
  SELECT
    $guid, (SELECT id FROM patches WHERE guid = $patch_guid), $patch_guid,
    $user_id, $subject_guid, NULL, $author_group_id, $author_group_guid,
    IIF($author_member_id < 0, NULL, $author_member_id),
    $group_id, $group_guid,
    IIF($group_member_id < 0, NULL, $group_member_id), julianday('now')
  RETURNING id
""".}

proc compute_hash*(obj: Subject | Paragraph | Patch | Article): string {.gcsafe.}

proc to_json_node*(subject: Subject): JsonNode =
  result = %*{"t": "subject", "n": subject.name}

proc to_json_node*(paragraph: Paragraph): JsonNode =
  result = %*{"t": "paragraph", "s": paragraph.style, "b": paragraph.text}

proc to_json_node*(patch: Patch): JsonNode =
  var pars: seq[string]
  for p in patch.paragraphs:
    if p.guid != "":
      pars.add(p.guid)
    else:
      pars.add(p.compute_hash())
  result = %*{
    "t": "patch",
    "p": pars
  }
  if patch.parent_guid != "":
    result["parent"] = %*patch.parent_guid

proc to_json_node*(art: Article): JsonNode =
  result = %*{
    "t": "article",
    "ts": art.timestamp,
    "p": art.patch_guid,
    "mod": if art.mod_article_guid.is_none: newJNull() else: %art.mod_article_guid.get,
    "r": %[%art.reply_guid, if art.reply_index.is_some: %art.reply_index.get else: newJNull()],
    "aut": art.author_group_guid,
    "autm": art.author_member_id,
    "g": art.group_guid,
    "gm": art.group_member_id
  }

proc compute_hash*(obj: Subject | Paragraph | Patch | Article): string {.gcsafe.} =
  result = obj.to_json_node().compute_hash()

proc create_article*(db: var Database, art: Article, parent_patch_id: string): int =
  assert(art.guid != "")
  var subject_guid: Option[string]
  if art.subject_name != "":
    var sub: Subject = (name: art.subject_name)
    subject_guid = some(sub.compute_hash())
    db.insert_subject(subject_guid.get, sub.name)

  var pat: Patch
  pat.parent_guid = parent_patch_id
  pat.paragraphs  = art.paragraphs
  var i = 0
  while i < pat.paragraphs.len:
    pat.paragraphs[i].guid = pat.paragraphs[i].compute_hash()
    i = i + 1
  pat.guid = pat.compute_hash()

  if db.get_patch_id(pat.guid).is_none:
    discard db.insert_patch(pat.guid, pat.parent_guid)
    var rank = 1
    for p in pat.paragraphs:
      db.insert_paragraph(p.guid, p.style, p.text)
      db.insert_patch_item(pat.guid, p.guid, rank)
      rank = rank + 1

  let author_group_id = art.author_group.id
  let author_group_guid = art.author_group.guid
  let author_member_id = if art.author_member == nil: -1 else: art.author_member.local_id
  let group_id = art.group.id
  let group_guid = art.group.guid
  let group_member_id = if art.group_member == nil: -1 else: art.group_member.local_id
  result = db.insert_article(art.guid, pat.guid, art.user_id, subject_guid, author_group_id, author_group_guid, author_member_id, group_id, group_guid, group_member_id).id

proc group_get_posts*(db: var Database, group_id: int): seq[Article] =
  result = @[]
  for row in db.articles_for_group(group_id):
    var a: Article
    a.id = row.id
    a.guid = row.guid
    a.patch_id = row.patch_id
    a.patch_guid = row.patch_guid
    a.user_id = row.user_id.get(-1)
    a.reply_guid = row.reply_guid.get("")
    a.reply_index = row.reply_index
    a.author_group_id = row.author_group_id
    a.author_group_guid = row.author_group_guid
    a.author_member_id = row.author_member_id
    a.group_id = row.group_id
    a.group_guid = row.group_guid
    a.group_member_id = row.group_member_id
    a.timestamp = row.timestamp
    a.score = row.score
    a.paragraphs = @[]

    for p in db.paragraphs(a.patch_id):
      a.paragraphs.add(p)

    result.add(a)

