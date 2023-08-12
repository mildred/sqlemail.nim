import std/strformat
import std/os
import std/asyncdispatch
import std/options

import easy_sqlite3
import smtp
import lmtp
import lmtp/address
import emailparser

import ./emaildb/migration
import ./emaildb/email
import ./litefs

proc to_strings(addrs: seq[Address]): seq[string] =
  result = @[]
  for addr in addrs:
    result.add($addr)

proc get_lmtp_handler*(dbdir: string, dbprefix: string, litefs: LiteFS): ClientCallback =
  result = proc(mail_from: seq[Address], rcpt_to: seq[Address], data: string): Future[string] {.gcsafe, async.} =
    result = ""
    if litefs.primary().is_none:
      let part = parse_email(data)
      for rcpt in rcpt_to:
        echo &"[{rcpt.local_part}] receiving e-mail"
        # let dbfile = user_database_name(dbdir, dbprefix, rcpt.local_part)
        var db = open_user_database(dbdir, dbprefix, rcpt.local_part)
        let id = db.insert_email(part)
        let raw_email = db.get_raw_email(id)
        echo &"[{rcpt.local_part}] received e-mail id={id} part_guid={raw_email.guid}"

        if raw_email.raw != data:
          echo &"[{rcpt.local_part}] e-mail id={id} incorrect data:\n{raw_email}"
    else:
      let primary = litefs.primary(cached = true).get
      try:
        let smtp = await dial_async(primary, Port(25), debug = true)
        await smtp.send_mail($mail_from[0], rcpt_to.to_strings(), data)
        await smtp.close()
      except:
        return "550 Requested action not taken: mailbox unavailable"
