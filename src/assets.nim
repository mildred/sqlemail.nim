import options

const editor_js = staticRead("../assets/editor.js")

proc getAsset*(file_path: string): Option[string] =
  case file_path
  of "assets/editor.js": return some(editor_js)
  else: none(string)
