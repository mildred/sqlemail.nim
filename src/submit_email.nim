import std/syncio
import std/parseopt
import std/strformat
import std/net
import std/asyncdispatch
import std/json
import std/options
import lmtp/utils/parse_port
import lmtp

import emailparser
import smtp {.all.}


const version {.strdefine.}: string = "(no version information)"

const doc = ("""
Usage: submit-email [options] FILE...

Tool part of sqlemail.

Options:
  -h, --help            Print help
  --version             Print version
  -L, --lmtp <addr>     Specify LMTP addr [default: localhost:2525]
  -S, --smtp <addr>     Specify SMTP addr [default is none]
  -t, --to <addr>       RCPT TO address
""") & (when not defined(version): "" else: &"""

Version: {version}
""")

proc send(address: string, port: Port, is_smtp: bool, email: string, to_addr: string) {.async.} =
  let protocol: string = if is_smtp: "smtp" else: "lmtp"
  echo &"Submitting {email} to {protocol}:{address}:{port}"
  let content = read_file(email)
  let jmap = envelope_to_jmap(content).get
  let sender = jmap["from"][0]["email"].get_str
  var to: seq[string] = @[]
  if to_addr != "":
    to.add(to_addr)
  else:
    for list in [jmap["to"], jmap["cc"], jmap["bcc"]]:
      if list.kind == JNull:
        continue
      for addr in list:
        to.add(addr["email"].get_str)

  if is_smtp:
    var smtp: Smtp = new_smtp(debug=true)

    # smtp.address = address
    # smtp.sock.connect(address, port)
    smtp.connect(address, port)
    # smtp.check_reply("220")
    # smtp.debug_send("LHLO localhost\c\L")
    # smtp.check_reply("250")
    smtp.send_mail(sender, to, content)
    smtp.close()
  else:
    var cx: lmtp.Connection = await connect(address, port)
    try:
      await cx.lhlo(address)
      await cx.mail_from(sender)
      for addr in to:
        await cx.rcpt_to(addr)
      await cx.send_data(content)
    finally:
      await cx.quit()

when isMainModule:
  var smtp_addr = "localhost:2525"
  var is_smtp = false
  var to_addr = ""

  var emails: seq[string] = @[]

  const shortNoVal = {'h'}
  const longNoVal = @["help", "version"]

  for kind, key, val in getopt(shortNoVal = shortNoVal, longNoVal = longNoVal):
    case kind
    of cmdArgument:
      emails.add(key)
    of cmdLongOption, cmdShortOption:
      case key
      of "lmtp", "L":  smtp_addr = val; is_smtp = false
      of "smtp", "S":  smtp_addr = val; is_smtp = true
      of "to", "t":  to_addr = val
      of "help", "h":
        echo doc
        quit()
      of "version":
        echo version
        when defined(version):
          quit(0)
        else:
          quit(1)
      else:
        echo "Unknown argument: " & key & " " & val
        quit(1)
    of cmdEnd: assert(false) # cannot happen

  if emails.len == 0:
    echo "No e-mail specified to submit"

  var address: string
  var port: Port
  (address, port) = parse_addr_and_port(smtp_addr, 25)


  for email in emails:
    waitFor send(address, port, is_smtp, email, to_addr)

