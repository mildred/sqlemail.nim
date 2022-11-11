import std/json
import std/algorithm
import easy_sqlite3

import ./guid

type
  GroupMemberItem* = tuple
    id: int
    group_member_id: int
    pod_url: string
    local_user_id: string

  GroupMember* = tuple
    id: int
    local_id: int
    group_item_id: int
    weight: float
    nickname: string
    user_id: int
    items: seq[GroupMemberItem]

  GroupItem* = tuple
    id: int
    guid: string
    root_guid: string
    parent_id: int
    parent_guid: string
    group_type: int
    name: string
    seed_userdata: string
    others_members_weight: float
    moderation_default_score: float
    members: seq[GroupMember]

proc cmp(a, b: GroupMemberItem): int =
  result = system.cmp[string](a.pod_url, b.pod_url)
  if result != 0: return result
  result = system.cmp[string](a.local_user_id, b.local_user_id)

proc cmp(a, b: GroupMember): int =
  result = system.cmp[int](a.local_id, b.local_id)

proc to_json_node(items: seq[GroupMemberItem]): JsonNode =
  result = newJArray()
  for m in items.sorted(cmp):
    result.add(%*[m.pod_url, m.local_user_id])

proc to_json_node(members: seq[GroupMember]): JsonNode =
  result = newJArray()
  for m in members.sorted(cmp):
    result.add(%*{
      "id": m.local_id,
      "nick": m.nickname,
      "w": m.weight,
      "addrs": m.items.to_json_node()
    })

proc to_json_node*(gi: GroupItem): JsonNode =
  result = %*{
    "t": "group-item",
    "n": gi.name,
    "gt": gi.group_type,
    "ud": gi.seed_userdata,
    "ow": gi.others_members_weight,
    "s": gi.moderation_default_score,
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

proc insert_group_item(guid, name, seed_userdata: string, group_type: int, others_members_weight: float, moderation_default_score: float) {.importdb: """
  INSERT INTO group_items (guid, root_guid, name, seed_userdata, group_type, others_members_weight, moderation_default_score)
  VALUES ($guid, $guid, $name, $seed_userdata, $group_type, $others_members_weight, $moderation_default_score)
  ON CONFLICT DO NOTHING
""".}

proc save_new*(db: var Database, gi: GroupItem) =
  assert(gi.guid != "")
  assert(gi.members.len == 0, "not yet implemented")
  db.insert_group_item(gi.guid, gi.name, gi.seed_userdata, gi.group_type, gi.others_members_weight, gi.moderation_default_score)

