import std/prelude
import std/strutils
import std/strformat
import std/base64
import std/uri
import std/json

import nimSHA2
import prologue
import jwt

import ../context

proc authorization_server*(ctx: Context) {.async, gcsafe.} =
  resp json_response(%*{
    "authorization_endpoint": % &"{ctx.request.url}/auth",
    "token_endpoint": % &"{ctx.request.url}/token"
  })

proc auth*(ctx: Context) {.async, gcsafe.} =
  let secretkey = AppContext(ctx).secretkey
  let state = ctx.getQueryParamsOption("state").get("")
  let redirect_uri = ctx.getQueryParamsOption("redirect_uri").get("")
  let code_challenge = ctx.getQueryParamsOption("code_challenge").get("")

  if redirect_uri == "":
    resp "Missing redirect_uri", Http400
    return

  if ctx.getQueryParamsOption("response_type").get("code") != "code":
    resp "Can only handle respose_type=code", Http400
    return

  if ctx.getQueryParamsOption("code_challenge_method").get("plain") != "S256":
    resp "Can only handle code_challenge_method=S256", Http400
    return

  let email = ctx.session.getOrDefault("email", "")
  if email != "":
    let code = base64.encode(computeSHA256(secretkey & code_challenge), safe = true).replace("=", "")
    var token = toJWT(%*{
      "header": {
        "alg": "HS256",
        "typ": "JWT"
      },
      "claims": {
        "userId": %email,
      }
    })
    token.sign(secretkey)
    let json_code: JsonNode = %{
      "code": %code,
      "token": % $token,
      # "code_challenge": %code_challenge, # debug
    }
    let resp_uri = parse_uri(redirect_uri) ? {
      "state": state,
      "code": base64.encode($json_code, safe = true).replace("=", "")
    }
    resp redirect($resp_uri)
    return

  let retry_auth_uri = ctx.request.url ? {
    "state": state,
    "redirect_uri": redirect_uri,
    "code_challenge": code_challenge,
    "response_type": "code",
    "code_challenge_method": "S256"
  }

  let login_uri = parse_uri("/login") ? { "redirect_url": $retry_auth_uri }

  resp redirect($login_uri)

proc token*(ctx: Context) {.async, gcsafe.} =
  let secretkey = AppContext(ctx).secretkey
  let grant_type = ctx.getFormParamsOption("grant_type").get("")

  case grant_type
  of "authorization_code":
    let json_code_b64 = ctx.getFormParamsOption("code").get("")
    let code_verifier = ctx.getFormParamsOption("code_verifier").get("")

    let code_challenge = base64.encode(computeSHA256(code_verifier), safe = true).replace("=", "")
    let deduced_code = base64.encode(computeSHA256(secretkey & code_challenge), safe = true).replace("=", "")

    let json_code = parse_json(base64.decode(json_code_b64))
    let code = json_code["code"].to(string)
    let token = json_code["token"].to(string)

    if code != deduced_code:
      resp &"Invalid code", Http401
      return

    resp json_response(%*{
      "access_token": %token,
      "token_type": %"bearer",
      "expires_in": %3600,
      "refresh_token": %token,
    })
  of "refresh_token":
    let refresh_token = ctx.getFormParamsOption("refresh_token").get("")
    if refresh_token == "":
      resp &"Missing refresh_token for grant_type={grant_type}", Http400
      return

    resp json_response(%*{
      "access_token": %refresh_token,
      "token_type": %"bearer",
      "expires_in": %3600,
      "refresh_token": %refresh_token,
    })
  else:
    resp &"Cannot handle grant_type={grant_type}", Http400

