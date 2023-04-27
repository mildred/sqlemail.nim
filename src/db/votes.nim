import std/json
import std/options
import std/algorithm
import easy_sqlite3

import ./guid
import ./groups
import ./articles

type
  Vote* = tuple
    id: int
    guid: string
    group_id: int
    group_guid: string
    member_local_user_id: int
    article_id: int
    article_guid: string
    paragraph_rank: Option[int]
    vote: float

proc to_json_node*(vote: Vote): JsonNode =
  result = %*{
    "g": vote.group_guid,
    "m": vote.member_local_user_id,
    "a": vote.article_guid,
    "v": vote.vote
  }
  if vote.paragraph_rank.is_some():
    result["p"] = %vote.paragraph_rank.get()

proc compute_hash*(obj: Vote): string =
  result = obj.to_json_node().compute_hash()

proc set_author*(vote: var Vote, group: GroupItem, member: GroupMember) =
  vote.group_id = group.id
  vote.group_guid = group.guid
  vote.member_local_user_id = member.local_id

proc set_article*(vote: var Vote, article: Article, paragraph_rank: int = -1) =
  vote.article_id = article.id
  vote.article_guid = article.guid
  if paragraph_rank >= 0:
    vote.paragraph_rank = some(paragraph_rank)

proc insert_vote(guid: string, group_id: int, group_guid: string, member_local_user_id, article_id: int, article_guid: string, paragraph_rank: Option[int], vote: float): tuple[id: int] {.importdb: """
  INSERT INTO votes (guid, group_id, group_guid, member_local_user_id, article_id, article_guid, paragraph_rank, vote)
  VALUES ($guid, $group_id, $group_guid, $member_local_user_id, $article_id, $article_guid, $paragraph_rank, $vote)
  ON CONFLICT DO NOTHING
  RETURNING id
""".}

proc save_new*(db: var Database, v: Vote): int =
  assert(v.guid != "")
  result = db.insert_vote(v.guid, v.group_id, v.group_guid, v.member_local_user_id, v.article_id, v.article_guid, v.paragraph_rank, v.vote).id


