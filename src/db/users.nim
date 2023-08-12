import std/options
import std/sysrand
import std/md5
import std/times
import std/json
import easy_sqlite3
import nauthy

proc hash_email*(email: string): string =
  #result = $sha1.secureHash(email)
  #result = get_md5(email)
 
  {.cast(noSideEffect).}:
    var
      c: MD5Context
      d: MD5Digest
    md5Init(c)
    md5Update(c, cstring(email), len(email))
    md5Final(c, d)
    result = $d

proc gen_totp*(issuer, email: string): Totp =
  var totp = initTotp(urandom(16), b32Decode = false)
  totp.uri = newUri(if issuer == "": "disputatio" else: issuer, email)
  result = totp

proc validate_totp*(totp_url: string, code: string, valid_duration: int64): bool =
  let now = getTime().toUnix()
  let valid_from = now - valid_duration
  let totp = otpFromUri(totp_url).totp
  var t = now
  while t > valid_from:
    if totp.verify(code, EpochSecond(t)):
      return true
    t = t - totp.interval
  return false

type
  User* = tuple
    id:         int
    local_part: string
    email:      string
    totp_url:   string

proc create_raw_user(email: string, local_part: string, totp_url: string): tuple[id: int] {.importdb: """
  INSERT INTO user (email, local_part, totp_url) VALUES ($email, $local_part, $totp_url) RETURNING id
""" .}

proc get_raw_user(email: string): Option[tuple[id: int, local_part: string, email: string, totp_url: string]] {.importdb: """
  SELECT id, local_part, email, totp_url FROM user WHERE email = $email
""" .}

proc get_user*(db: var Database, email: string): Option[User] =
  if email == "":
    return none(User)

  let u = db.get_raw_user(email)
  if u.is_none():
    return none(User)

  var res: User
  res.id = u.get.id
  res.local_part = u.get.local_part
  res.email = u.get.email
  res.totp_url = u.get.totp_url
  return some(res)

proc create_user*(db: var Database, email, totp_url: string): User =
  let email_hash = hash_email(email)
  let user_id = db.create_raw_user(email, email_hash, totp_url)
  result = db.get_user(email).get()

proc `%`*(u: User): JsonNode = 
  result = %{
    "email": %u.email,
    "local_part": %u.local_part,
  }

