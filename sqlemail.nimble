# Package

version       = "0.1.0"
author        = "Mildred Ki'Lya"
description   = "Email database accessible via SQL from client-side"
license       = "AGPL-3.0-or-later"
srcDir        = "src"
bin           = @["sqlemail"]


# Dependencies

requires "nim >= 1.6.6"

requires "https://github.com/mildred/prologue#allow-custom-socket"
requires "easysqlite3#head"
requires "templates"
requires "nauthy"
requires "https://github.com/mildred/nim_qr.git#master"
requires "libp2p"
requires "canonicaljson"
requires "smtp#head"
requires "embedfs"
requires "nimsha2"
requires "jwt"
requires "emailparser"
requires "https://github.com/mildred/lmtp.nim#head"
requires "prologue_passwordless_login"
