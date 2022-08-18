import prologue
import prologue/middlewares/sessions/signedcookiesession
from prologue/core/urandom import random_string

import docopt

import ./db/migration
import ./utils/parse_port
import ./routes
import ./context

const version {.strdefine.}: string = "(no version information)"

const doc = ("""
Nimnews is a simple newsgroup NNTP server

Usage: nimnews [options]

Options:
  -h, --help            Print help
  --version             Print version
  -p, --port <port>     Specify a different port [default: 8080]
                        Specify sd=0 for first systemd socket activation
                        or specify sd=[NAME:]N
  --secretkey <key>     Secret key for HTTP sessions
  -d, --db <file>       Database file [default: ./disputatio.sqlite]
""") & (when not defined(version): "" else: &"""

Version: {version}
""")


when isMainModule:
  let args = docopt(doc)

  if args["--version"]:
    echo version
    when defined(version):
      quit(0)
    else:
      quit(1)

  let
    arg_fd               = parse_sd_socket_activation($args["--port"])
    (arg_addr, arg_port) = parse_addr_and_port($args["--port"], 119)

  var secretkey = $args["--secretkey"]
  if secretkey == "":
    secretkey = random_string(8)

  if arg_fd != -1:
    echo "Unsupported systemd socket activation of file descriptor inheritance"
    echo "See: <https://github.com/ringabout/httpx/issues/12>"
    quit(1)

  let db = open_database($args["--db"])
  discard db

  let settings = newSettings(address = arg_addr, port = arg_port, secret_key = secret_key)
  var app = newApp(settings)
  app.use(contextMiddleware($args["--db"]))
  app.use(sessionMiddleware(settings))
  init_routes(app)
  app.run(AppContext)
