import std/json
import easy_sqlite3

import ./guid

type
  GroupMember* = tuple
    id: string
    group_item_id: int
    weight: float
    pod_url: string
    nickname: string
    local_user_id: string
    user_id: int

  GroupItem* = tuple
    id: int
    guid: string
    root_guid: string
    parent_id: int
    parent_guid: string
    seed_userdata: string
    others_members_weight: float
    moderation_default_score: float
    members: seq[GroupMember]

proc to_json_node(members: seq[GroupMember]): JsonNode =
  result = newJObject()
  for m in members:
    if m.nickname == "": continue
    var obj: JsonNode = result
    if not obj.contains(m.nickname): obj[m.nickname] = newJObject()
    obj = obj[m.nickname]
    if not obj.contains(m.pod_url): obj[m.pod_url] = newJObject()
    obj = obj[m.pod_url]
    if not obj.contains(m.local_user_id): obj[m.local_user_id] = newJObject()
    obj = obj[m.local_user_id]
    obj["w"] = %*m.weight

proc to_json_node*(gi: GroupItem): JsonNode =
  result = %*{
    "t": "group-item",
    "ud": gi.seed_userdata,
    "wom": gi.others_members_weight,
    "mds": gi.moderation_default_score,
    "m": gi.members.to_json_node()
  }
  if gi.root_guid != "":
    result["root"] = %*gi.root_guid
  if gi.parent_guid != "":
    result["parent"] = %*gi.parent_guid

proc compute_hash*(obj: GroupItem): string =
  result = obj.to_json_node().compute_hash()

proc compute_new*(gi: var GroupItem) =
  gi.guid = gi.compute_hash()

proc insert_group_item(guid, seed_userdata: string, others_members_weight, moderation_default_score: float) {.importdb: """
  INSERT INTO group_items (guid, root_guid, seed_userdata, others_members_weight, moderation_default_score)
  VALUES ($guid, $guid, $seed_userdata, $others_members_weight, $moderation_default_score)
  ON CONFLICT DO NOTHING
""".}

proc save_new*(db: var Database, gi: GroupItem) =
  assert(gi.guid != "")
  assert(gi.members.len == 0, "not yet implemented")
  db.insert_group_item(gi.guid, gi.seed_userdata, gi.others_members_weight, gi.moderation_default_score)

