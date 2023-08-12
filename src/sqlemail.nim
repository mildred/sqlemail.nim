import std/os
import std/parseopt
import std/strutils
import std/strformat
import std/net
import std/asyncnet
import std/asyncdispatch
import prologue
import lmtp
import lmtp/utils/parse_port
import prologue/middlewares/sessions/signedcookiesession
from prologue/core/urandom import random_string

import ./context
import ./routes
import ./lmtp_handler
import ./litefs
import ./db/migration

const version {.strdefine.}: string = "(no version information)"

const doc = ("""
Usage: sqlemail [options]

Options:
  -h, --help            Print help
  --version             Print version
  -H, --http <addr>     Specify HTTP listen addr [default: localhost:8080]
  -L, --lmtp <addr>     Specify LMTP listen addr [default: localhost:2525]
  --secretkey <key>     Secret key for HTTP sessions
  -d, --db <file>       Database file [default: ./sqlemail.db]
  -D, --dbdir <dir>     Database directory for user databases [default: users]
  --dbprefix <prefix>   Database filename prefix [default is empty]
  --assets <dir>        Assets directory [default: ./assets/]
  --smtp <server>       SMTP server for sending e-mails
  --sender <email>      Sending address for e-mails
  --fqdn <fqdn>         FQDN for LMTP LHLO [default: sqlemail]
""") & (when not defined(version): "" else: &"""

Version: {version}
""")


when isMainModule:
  var http_listen = "localhost:8080"
  var lmtp_listen = "localhost:2525"
  var secretkey = ""
  var dbfile = "./sqlemail.db"
  var dbdir = "users"
  var dbprefix = ""
  var assets = "./assets/"
  var smtp_host = ""
  var smtp_port: Port = Port(25)
  var sender = ""
  var fqdn = "sqlemail"

  const shortNoVal = {'h'}
  const longNoVal = @["help", "version"]

  for kind, key, val in getopt(shortNoVal = shortNoVal, longNoVal = longNoVal):
    case kind
    of cmdArgument:
      echo "Unknown argument " & key
      quit(1)
    of cmdLongOption, cmdShortOption:
      case key
      of "http", "H":  http_listen = val
      of "lmtp", "L":  lmtp_listen = val
      of "secretkey":  secretkey = val
      of "db", "d":    dbfile = val
      of "dbdir", "D": dbdir = val
      of "dbprefix":   dbprefix = val
      of "assets":     assets = val
      of "smtp":       (smtp_host, smtp_port) = parse_addr_and_port(val, 25)
      of "sender":     sender = val
      of "fqdn":       fqdn = val
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

  if secretkey.len == 0:
    secretkey = random_string(16).to_hex()
    echo "Using secret key: " & secretkey

  var http_addr: string
  var http_port: Port
  (http_addr, http_port) = parse_addr_and_port(http_listen, 8080)
  if http_addr == "": http_addr = "localhost"
  if http_port == Port(0): http_port = Port(8080)
  let http_settings = newSettings(address = http_addr, port = http_port, secretkey = secretkey)

  let db = open_database(dbfile)
  discard db

  var lmtp_server: AsyncSocket
  lmtp_server.listen_socket(lmtp_listen)
  asyncCheck lmtp_server.serve(fqdn, get_lmtp_handler(dbdir, dbprefix, newLiteFS(dbdir)))

  var app = newApp(http_settings)
  app.use(contextMiddleware(dbfile, assets, smtp_host, smtp_port, sender, secretkey, dbdir, dbprefix))
  app.use(sessionMiddleware(http_settings))
  init_routes(app)
  asyncCheck app.runAsync(AppContext)

  while true:
    try:
      runForever()
    except:
      echo "----------"
      let e = getCurrentException()
      #echo getStackTrace(e)
      echo &"{e.name}: {e.msg}"
      echo "----------"
