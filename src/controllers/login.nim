import std/uri
import std/strformat
import std/options
import std/cgi
import std/times
import std/smtp
import nauthy

import ../utils/parse_port
import ../context
import ../db/users
import ../views/[layout, login_form, login_totp, logout_form]

import prologue

proc send_email(smtp_conn: string, sender, recipient: string, msg: string) =
  if smtp_conn == "":
    echo &"No SMTP configured, failed to send e-mail:\nMAIL FROM: {sender}\nRCPT TO: {recipient}\n{msg}"
    return

  echo &"Connecting to {smtp_conn}"
  let (smtp_server, smtp_port) = parse_addr_and_port(smtp_conn, 25)
  var smtpConn = newSmtp()
  smtpConn.connect(smtp_server, smtp_port)
  defer: smtpConn.close()
  smtpConn.sendMail(sender, @[recipient], msg)

proc send_code(ctx: AppContext, email, code: string, url: uri.Uri) =
  send_email(ctx.smtp, ctx.sender, email, $createMessage(
    &"Your {url.hostname} login code: {code}",
    &"To log-in to {url.hostname}, please click the following link:\n\n" &
    &"\t{url}\n\n" &
    &"Then enter the following code:\n\n" &
    &"\t{code}\n\n" &
    &"-- \n" &
    &"{url.hostname}\n" &
    &"Please do not reply to this automated message",
    @[email], @[],
    @[
      ("X-Login-URL", $(url / code)),
      ("X-Login-Code", code)
    ]))

proc get*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let email = ctx.getPathParams("email", "")
  let code = ctx.getPathParams("code", "")
  let email_hash = hash_email(email)
  let user = db[].get_user(email_hash)

  # No email: provide login form to ask for email
  if email == "" or user.is_none():
    resp ctx.layout(login_form(), title = "Login")
    return

  let totp_url = user.get().get_email(email_hash).get().totp_url
  let totp = otpFromUri(totp_url).totp

  # If it corresponds to the current user, show the TOTP URL
  if user.is_some:
    let current_user = user.get().get_email(hash_email(ctx.session.getOrDefault("email", "")))
    if current_user.is_some():
      resp ctx.layout(login_totp_ok(totp_url) & login_totp(email, code), title = "TOTP")
      return

  resp ctx.layout(login_totp(email, code), title = "Login")

proc post*(ctx: Context) {.async, gcsafe.} =
  var totp: Totp
  let db = AppContext(ctx).db
  let email = ctx.getPostParamsOption("email").get()
  let email_hash = hash_email(email)
  let otp = ctx.getPostParamsOption("otp")
  let user = db[].get_user(email_hash)

  # No code provided or the user does not exists
  if otp.is_none() or user.is_none():
    # If user does not exists, create totp secret and send email with code
    if user.is_none():
      totp = gen_totp(ctx.request.hostName, email)
      discard db[].create_user(email_hash, totp.build_uri())
    else:
      let totp_url = user.get().get_email(email_hash).get().totp_url
      totp = otpFromUri(totp_url).totp

    # Send code via e-mail
    let code = totp.now()
    var url = ctx.request.url / email
    url.hostname = ctx.request.headers["host", 0]
    url.scheme = if ctx.request.secure: "https" else: "http"
    echo &"TOTP code for {email}: {code}"
    send_code(AppContext(ctx), email, code, url)

    resp redirect("/login/" & email.encodeUrl())
    return

  # code provided, check with OTP secret and store user in session
  # if user email has not been validated, mark as valid and provide OTP
  # secret URI

  let totp_url = user.get().get_email(email_hash).get().totp_url
  if not validate_totp(totp_url, otp.get, 10*60):
    resp ctx.layout(login_form(), title = "Retry Login")
    return

  db[].user_email_mark_valid(email_hash)
  ctx.session["email"] = email

  resp ctx.layout(login_totp_ok(totp_url), title = "Login succeeded")

proc get_logout*(ctx: Context) {.async, gcsafe.} =
  resp ctx.layout(logout_form(), title = "Logout")

proc post_logout*(ctx: Context) {.async, gcsafe.} =
  ctx.session.del("email")
  resp redirect("/")
