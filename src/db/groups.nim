import std/json
import ./guid

type
  GroupMember* = tuple
    id: string
    group_item_id: int
    weight: float
    pod_url: string
    local_user_id: string
    user_id: int

  GroupItem* = tuple
    id: int
    guid: string
    root_guid: string
    parent_id: int
    parent_guid: string
    userdata: string
    others_members_weight: float
    moderation_default_score: float
    members: seq[GroupMember]

proc compute_hash*(obj: GroupItem): string =
  result = obj.to_json_node().compute_hash()

proc to_json_node(members: seq[GroupMember]): JsonNode =
  result = newJObject()
  for m in members:
    var obj: JsonNode = result
    if not obj.contains(m.nickname): obj[m.nickname] = newJObject()
    obj = obj[m.nickname]
    if not obj.contains(m.pod_url): obj[m.pod_url] = newJObject()
    obj = obj[m.pod_url]
    if not obj.contains(m.local_user_id): obj[m.local_user_id] = newJObject()
    obj = obj[m.local_user_id]
    obj["w"] = m.weight

proc to_json_node*(gi: GroupItem): JsonNode =
  result = %*{
    "t": "group-item",
    "ud": gi.userdata,
    "wom": gi.others_members_weight,
    "mds": gi.moderation_default_score,
    "m": gi.members.to_json_node()
  }
  if gi.root_guid != "":
    result["root"] = gi.root_guid
  if gi.parent_guid != "":
    result["parent"] = gi.parent_guid

