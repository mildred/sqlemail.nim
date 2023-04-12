import prologue
import prologue/middlewares/sessions/signedcookiesession
from prologue/core/urandom import random_string

import ./db/migration
import ./utils/parse_port
import ./routes
import ./context

const version {.strdefine.}: string = "(no version information)"

const doc = ("""
Usage: disputatio [options]

Options:
  -h, --help            Print help
  --version             Print version
  -p, --listen <addr>   Specify a different port [default: localhost:8080]
                        Specify sd=0 for first systemd socket activation
                        or specify sd=[NAME:]N
  --secretkey <key>     Secret key for HTTP sessions
  -d, --db <file>       Database file [default: ./disputatio.sqlite]
  --assets <dir>        Assets directory [default: ./assets/]
  --smtp <server>       SMTP server for sending e-mails
  --sender <email>      Sending address for e-mails
""") & (when not defined(version): "" else: &"""

Version: {version}
""")


when isMainModule:
  let settings = newSettings(address = "localhost", port = Port(8080))
  let secretkey = ""
  let dbfile = "./disputatio.sqlite"
  let assets = "./assets/"
  let smtp = ""
  let sender = ""

  const shortNoVal = {'h'}
  const longNoVal = @["help", "version"]

  for kind, key, val in getopt(shortNoVal = shortNoVal, longNoVal = longNoVal):
    case kind
    of cmdArgument:
      discard
    of cmdLongOption, cmdShortOption:
      case key
      of "listen":
        let arg_fd               = parse_sd_socket_activation(val)
        let (arg_addr, arg_port) = parse_addr_and_port(val, 8080)

        if arg_fd != -1:
          echo "Unsupported systemd socket activation of file descriptor inheritance"
          echo "See: <https://github.com/ringabout/httpx/issues/12>"
          quit(1)

        settings.address = arg_addr
        settings.port = arg_port
      of "secretkey": secretkey = val
      of "db":     dbfile = val
      of "assets": assets = val
      of "smtp":   smtp = val
      of "sender": sender = val
      of "help", "h":
        echo doc
        quit()
      of "version":
        echo version
        when defined(version):
          quit(0)
        else:
          quit(1)
    of cmdEnd: assert(false) # cannot happen

  if secretkey.len == 0:
    secretkey = random_string(8)
  settings.secretkey = secretkey

  let db = open_database(dbfile)
  discard db

  var app = newApp(settings)
  app.use(contextMiddleware(dbfile, assets, smtp, sender))
  app.use(sessionMiddleware(settings))
  init_routes(app)
  app.run(AppContext)
