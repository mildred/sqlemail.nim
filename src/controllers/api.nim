import std/prelude
import std/strutils
import std/strformat
import std/base64
import std/uri
import std/json

import prologue

import ../context

proc get*(ctx: Context) {.async, gcsafe.} =
  resp json_response(%*{
    "ok": %true
  })
