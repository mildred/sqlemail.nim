import std/options
import std/os
import std/strutils
import std/strformat
import std/parseutils

type LiteFS* = ref object
  path*: string
  cached_primary: Option[Option[string]]

proc newLiteFS*(path: string): LiteFS =
  result = LiteFS(path: path, cached_primary: none(Option[string]))

proc primary*(litefs: LiteFS, cached: bool = false): Option[string] =
  if cached and litefs.cached_primary.is_some:
    return litefs.cached_primary.get
  try:
    let primary = read_lines(litefs.path / ".primary", 1)
    result = some(primary[0])
  except IOError:
    result = none(string)
  litefs.cached_primary = some(result)

proc txid_checksum*(litefs: LiteFS, dbname: string): tuple[txid: uint64, checksum: uint64] =
  result.txid = 0
  result.checksum = 0
  var path = dbname & "-pos"
  if not path.starts_with("/"):
    path = litefs.path / path
  let content = read_lines(path, 1)
  let slice = content[0].split('/')
  let txid_str = slice[0]
  let chksum_str = slice[1]
  discard parse_hex[uint64](txid_str, result.txid)
  discard parse_hex[uint64](chksum_str, result.checksum)

proc txid*(litefs: LiteFS, dbname: string): uint64 =
  result = litefs.txid_checksum(dbname).txid
