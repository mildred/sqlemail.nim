import std/prelude
import std/strutils
import std/strformat
import std/base64
import std/uri
import std/json

import prologue
import easy_sqlite3

import ../context

proc get*(ctx: Context) {.async, gcsafe.} =
  resp json_response(%*{
    "ok": %true
  })

proc post*(ctx: Context) {.async, gcsafe.} =
  let req = parse_json(ctx.request.body())

  let sql = req["sql"].to(string)
  if sql == "":
    resp json_response(%*{ "ok": %true })
    return

  var db = initDatabase(":memory:")
  db.setAuthorizer do (code: AuthorizerActionCode, arg3, arg4, arg5, arg6: Option[string]) -> AuthorizerResult:
    result = deny
    case code
    of select:
      result = ok
    of function:
      case arg4.get("")
      of "count":
        result = ok
      else:
        result = deny
    else:
      discard
    echo &"authorize {code} {arg3} {arg4} {arg5} {arg6} = {result}"

  let st = db.newStatement(sql)
  var res_lines: seq[JsonNode]
  for line in st.lines():
    var res_line: seq[JsonNode]
    for col in line:
      case col.data_type
      of dt_integer:
        res_line.add(%col[int])
      of dt_float:
        res_line.add(%col[float64])
      of dt_text:
        res_line.add(%col[string])
      of dt_blob:
        res_line.add(%col[string])
      of dt_null:
        res_line.add(newJNull())
    res_lines.add(%res_line)

  resp json_response(%*{ "lines": %res_lines })
