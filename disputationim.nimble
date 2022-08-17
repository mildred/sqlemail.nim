# Package

version       = "0.1.0"
author        = "Mildred Ki'Lya"
description   = "Moderated article database with possible federation"
license       = "AGPL-3.0-or-later"
srcDir        = "src"
bin           = @["disputationim"]


# Dependencies

requires "nim >= 1.6.6"

requires "prologue"
requires "docopt"
requires "easysqlite3"
requires "templates"
