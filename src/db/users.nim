import std/options
import std/sysrand
import std/md5
import std/times
import easy_sqlite3
import nauthy

func hash_email*(email: string): string =
  #result = $sha1.secureHash(email)
  #result = get_md5(email)

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
  UserEmail* = tuple
    email_hash: string
    totp_url: string
    valid: bool
  UserPod* = tuple
    pod_url: string
  User* = tuple
    id:     int
    emails: seq[UserEmail]
    pods:   seq[UserPod]

proc get_email*(u: User, email_hash: string): Option[UserEmail] =
  for e in u.emails:
    if e.email_hash == email_hash:
      return some(e)

proc create_user_id(): tuple[id: int] {.importdb: """
  INSERT INTO users DEFAULT VALUES RETURNING id
""" .}

proc create_user_email(user_id: int, email_hash, totp_url: string, valid: bool) {.importdb: """
  INSERT INTO user_emails (user_id, email_hash, totp_url, valid) VALUES($user_id, $email_hash, $totp_url, $valid)
""" .}

proc user_email_mark_valid*(email_hash: string, valid: bool = true) {.importdb: """
  UPDATE user_emails SET valid = $valid WHERE email_hash = $email_hash
""" .}

proc get_user_id(email_hash: string): Option[tuple[user_id: int]] {.importdb: """
  SELECT user_id FROM user_emails WHERE email_hash = $email_hash
""" .}

iterator get_pods(user_id: int): tuple[pod_url: string] {.importdb: """
  SELECT pod_url from user_pods WHERE user_id = $user_id
""".} = discard

iterator get_emails(user_id: int): tuple[email_hash: string, totp_url: string, valid: bool] {.importdb: """
  SELECT email_hash, totp_url, valid FROM user_emails WHERE user_id = $user_id
""".} = discard

proc get_user*(db: var Database, email_hash: string): Option[User] =
  let user_id = db.get_user_id(email_hash)
  if user_id.is_none():
    return none(User)

  var res: User
  res.id = user_id.get.user_id
  res.pods = @[]
  res.emails = @[]
  for e in db.get_emails(user_id.get().user_id): res.emails.add(e)
  for p in db.get_pods(user_id.get().user_id): res.pods.add(p)
  return some(res)

proc create_user*(db: var Database, email_hash, totp_url: string): User =
  let user_id = db.create_user_id()
  db.create_user_email(user_id.id, email_hash, totp_url, false)
  result = db.get_user(email_hash).get()
