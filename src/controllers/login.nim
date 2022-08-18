import std/strformat
import std/options
import std/cgi
import std/times
import nauthy

import ../context
import ../db/users
import ../views/[layout, login_form, login_totp]

import prologue

proc get*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let email = ctx.getPathParams("email", "")
  let email_hash = hash_email(email)
  let user = db[].get_user(email_hash)

  # No email: provide login form to ask for email
  if email == "" or user.is_none():
    resp layout(login_form(), title = "Login")
    return

  let totp_url = user.get().get_email(email_hash).get().totp_url
  let totp = otpFromUri(totp_url).totp

  # If it corresponds to the current user, show the TOTP URL
  if user.is_some:
    let current_user = user.get().get_email(hash_email(ctx.session.getOrDefault("email", "")))
    if current_user.is_some():
      resp layout(login_totp_ok(totp_url), title = "TOTP")
      return

  # Email provided, ask for code
  # TODO: send email
  echo &"TOTP code for {email}: {totp.now()}"
  resp layout(login_totp(email), title = "Login")

proc post*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let email = ctx.getPostParamsOption("email").get()
  let email_hash = hash_email(email)
  let otp = ctx.getPostParamsOption("otp")
  let user = db[].get_user(email_hash)

  # No code provided or the user does not exists
  if otp.is_none() or user.is_none():
    # If user does not exists, create totp secret and send email with code
    if user.is_none():
      let totp = gen_totp(ctx.request.hostName, email)
      discard db[].create_user(email_hash, totp.build_uri())
    resp redirect("/login/" & email.encodeUrl())
    return

  # code provided, check with OTP secret and store user in session
  # if user email has not been validated, mark as valid and provide OTP
  # secret URI

  let totp_url = user.get().get_email(email_hash).get().totp_url
  if not validate_totp(totp_url, otp.get, 10*60):
    resp layout(login_form(), title = "Retry Login")
    return

  db[].user_email_mark_valid(email_hash)
  ctx.session["email"] = email

  resp layout(login_totp_ok(totp_url), title = "Login succeeded")

