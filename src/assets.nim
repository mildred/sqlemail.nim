import tables, base64

var assets: Table[string, string]

proc getAsset*(path: string): string =
  result = assets[path].decode()

func toByteSeq(str: string): seq[byte] {.inline.} =
  ## Copy ``string`` memory into an immutable``seq[byte]``.
  let length = str.len
  if length > 0:
    result = newSeq[byte](length)
    copyMem(result[0].unsafeAddr, str[0].unsafeAddr, length)

proc getAssetToByteSeq*(path: string): seq[byte] =
  result = toByteSeq (getAsset path)

assets["assets/editor.js"] = """Y29uc29sZS5sb2coImVkaXRvci5qcyIpCg=="""

