import std/cgi

proc h*(s: string): string = xmlEncode(s)
