import std/strformat
import std/cgi
import std/math

proc h*(s: string): string = xmlEncode(s)

func format_time*(timestamp: float): string =
  let frac = (timestamp - 0.5) - floor(timestamp - 0.5)
  let hours = floor(frac * 24.0)
  let hours_i = int(hours)
  let minutes = int(floor(24.0 * 60.0 * (frac - (hours / 24.0))))
  result = &"{hours_i}:{minutes:02}"
