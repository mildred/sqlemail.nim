import std/json
import canonicaljson
import libp2p/multihash

proc compute_hash*(input: JsonNode): string =
  result = $MultiHash.digest("sha2-256", cast[seq[byte]](canonify(input))).get()


