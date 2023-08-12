import std/json
import canonicaljson
import libp2p/multihash

proc compute_hash*(input: JsonNode): string =
  result = MultiHash.digest("sha2-256", cast[seq[byte]](canonify(input))).get().base58()

proc compute_hash*(input: string): string =
  result = MultiHash.digest("sha2-256", cast[seq[byte]](input)).get().base58()


