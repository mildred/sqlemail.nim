import std/uri
import std/strformat
import std/strutils
import std/options
import std/cgi
import std/times
import std/httpclient
import std/parseutils
import smtp
import nauthy

import ../db/users

import ../context
import ../views/[layout, login_form, login_totp, logout_form]

import prologue

proc send_email(smtp_host: string, smtp_port: Port, sender, recipient: string, msg: string) =
  if smtp_host == "":
    echo &"No SMTP configured, failed to send e-mail:\nMAIL FROM: {sender}\nRCPT TO: {recipient}\n{msg}"
    return

  echo &"Connecting to {smtp_host}:{smtp_port}"
  var smtpConn = newSmtp()
  smtpConn.connect(smtp_host, smtp_port)
  defer: smtpConn.close()
  smtpConn.sendMail(sender, @[recipient], msg)

proc send_code_email(ctx: AppContext, email, code: string, url: uri.Uri) =
  send_email(ctx.smtp_host, ctx.smtp_port, ctx.sender, email, $createMessage(
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

proc send_code(ctx: AppContext, email: string, totp: Totp) =
  let code = totp.now()
  var url = ctx.request.url / email
  url.hostname = ctx.request.headers["host", 0]
  url.scheme = if ctx.request.secure: "https" else: "http"
  echo &"TOTP code for {email}: {code}"
  send_code_email(ctx, email, code, url)

proc get*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let redirect_url = ctx.getQueryParamsOption("redirect_url").get("")
  let email = ctx.getPathParams("email", "")
  let code = ctx.getPathParams("code", "")
  let email_hash = hash_email(email)
  let user = db[].get_user(email)

  # No email: provide login form to ask for email
  if email == "" or user.is_none():
    resp ctx.layout(login_form(redirect_url), title = "Login")
    return

  let totp_url = user.get.totp_url
  let totp = otpFromUri(totp_url).totp

  # If it corresponds to the current user, show the TOTP URL
  if user.is_some:
    resp ctx.layout(login_totp_ok(totp_url) & login_totp(email, code, redirect_url), title = "TOTP")
    return

  resp ctx.layout(login_totp(email, code, redirect_url), title = "Login")

proc create_user(ctx: AppContext, email: string) {.async.} =
  if ctx.litefs.primary().is_none:
    let totp = gen_totp(ctx.request.hostName, email)
    discard ctx.db[].create_user(email, totp.build_uri())
    send_code(ctx, email, totp)
    ctx.response.setHeader("X-SQLEmail-TxId", ctx.db_txid().to_hex())
  else:
    let primary = ctx.litefs.primary(cached = true).get
    # TODO: send POST request to primary to create email
    # TODO: wait for the replication to take place before/after redirect
    var client = newAsyncHTTPClient()
    var multipart: MultipartData
    multipart["email"] = email
    let primary_url = &"https://{primary}/login"
    echo &"Redirect to {primary_url}"
    let resp = await client.post(primary_url, multipart = multipart)
    let txid_hex: string = resp.headers.get_or_default("X-SQLEmail-TxId")
    var txid: uint64
    discard parse_hex[uint64](txid_hex, txid)
    echo &"User will be updated when txid={txid_hex}"

proc post*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let redirect_url = ctx.getPostParamsOption("redirect_url").get("")
  let email = ctx.getPostParamsOption("email").get()
  let email_hash = hash_email(email)
  let otp = ctx.getPostParamsOption("otp")
  let user = db[].get_user(email)

  # No code provided or the user does not exists
  if otp.is_none() or user.is_none():
    # If user does not exists, create totp secret and send email with code
    if user.is_none():
      await create_user(AppContext(ctx), email)
    else:
      let totp_url = user.get.totp_url
      let totp = otpFromUri(totp_url).totp
      send_code(AppContext(ctx), email, totp)

    resp redirect($ (parse_uri("/login/" & email.encodeUrl()) ? { "redirect_url": redirect_url }))
    return

  # code provided, check with OTP secret and store user in session
  # if user email has not been validated, mark as valid and provide OTP
  # secret URI

  let totp_url = user.get.totp_url
  if not validate_totp(totp_url, otp.get, 10*60):
    resp ctx.layout(login_form(redirect_url), title = "Retry Login")
    return

  var pod_url = ctx.request.url / email
  pod_url.hostname = ctx.request.headers["host", 0]
  pod_url.scheme = if ctx.request.secure: "https" else: "http"
  pod_url.path = "/"

  ctx.session["email"] = email

  if redirect_url != "":
    resp redirect(redirect_url)
    return

  resp ctx.layout(login_totp_ok(totp_url), title = "Login succeeded")

proc get_logout*(ctx: Context) {.async, gcsafe.} =
  resp ctx.layout(logout_form(), title = "Logout")

proc post_logout*(ctx: Context) {.async, gcsafe.} =
  ctx.session.del("email")
  resp redirect("/")
