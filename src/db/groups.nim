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

proc insert_group_item(guid, name, seed_userdata: string, group_type: int, others_members_weight: float, moderation_default_score: float): tuple[id: int] {.importdb: """
  INSERT INTO group_items (guid, root_guid, name, seed_userdata, group_type, others_members_weight, moderation_default_score)
  VALUES ($guid, $guid, $name, $seed_userdata, $group_type, $others_members_weight, $moderation_default_score)
  ON CONFLICT DO NOTHING
  RETURNING id
""".}

proc insert_group_member(local_id: int, group_item_id: int, nickname: string, weight: float, user_id: int): tuple[id: int] {.importdb: """
  INSERT INTO group_members (local_id, obsolete, obsoleted_by, group_item_id, nickname, weight, user_id)
  VALUES ($local_id, FALSE, NULL, $group_item_id, $nickname, $weight, CASE WHEN $user_id <= 0 THEN NULL ELSE $user_id END)
  RETURNING id
""".}

proc insert_group_member_item(group_member_id: int, pod_url: string, local_user_id: string): tuple[id: int] {.importdb: """
  INSERT INTO group_member_items (group_member_id, pod_url, local_user_id)
  VALUES ($group_member_id, $pod_url, $local_user_id)
  RETURNING id
""".}

iterator select_root_group_item_by_user_id(user_id: int): tuple[
    id: int,
    guid: string,
    root_guid: string,
    parent_id: int,
    parent_guid: string,
    group_type: int,
    name: string,
    seed_userdata: string,
    others_members_weight: float,
    moderation_default_score: float
] {.importdb: """
  SELECT  id, guid, root_guid, parent_id, parent_guid, group_type, name,
          seed_userdata, others_members_weight, moderation_default_score
  FROM    group_items
  WHERE guid = (
    SELECT root_guid
    FROM group_items gi JOIN group_members gm ON gi.id = gm.group_item_id
    WHERE NOT obsolete AND user_id = $user_id
  )
""".} = discard

proc save_new*(db: var Database, gi: GroupItem) =
  assert(gi.guid != "")
  for member in gi.members:
    assert(member.items.len > 0, "group member must have pods")

  let group = db.insert_group_item(gi.guid, gi.name, gi.seed_userdata, gi.group_type, gi.others_members_weight, gi.moderation_default_score)
  for member in gi.members:
    let mem = db.insert_group_member(member.local_id, group.id, member.nickname, member.weight, member.user_id)
    for item in member.items:
      discard db.insert_group_member_item(mem.id, item.pod_url, item.local_user_id)

proc list_groups_with_user*(db: var Database, user_id: int): seq[GroupItem] =
  result = @[]
  for g in db.select_root_group_item_by_user_id(user_id):
    let gi: GroupItem = (
      id: g.id, guid: g.guid, root_guid: g.root_guid, parent_id: g.parent_id,
      parent_guid: g.parent_guid, group_type: g.group_type, name: g.name,
      seed_userdata: g.seed_userdata,
      others_members_weight: g.others_members_weight,
      moderation_default_score: g.moderation_default_score,
      members: @[])
    result.add(gi)

