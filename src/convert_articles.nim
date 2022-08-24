import std/strutils
import std/strformat
import std/htmlparser
import std/xmltree
import ./db/articles
import ./views/common

type
  StyleItem* = tuple
    merge_previous: bool
    name: string
    classes: seq[string]
  Style* = tuple
    path: seq[StyleItem]

proc parse_style*(style: string): Style =
  for i in style.split(" "):
    var item_str = i
    var item: StyleItem
    item.merge_previous = false
    if item_str.starts_with("="):
      item.merge_previous = true
      item_str = item_str[1..^1]
    elif item_str.starts_with("+"):
      item_str = item_str[1..^1]
    let parts = item_str.split(".")
    if parts.len >= 1:
      item.name = parts[0]
      item.classes = parts[1..^1]
      result.path.add(item)
  if result.path.len > 0:
    result.path[result.path.len - 1].merge_previous = false

proc html_close_open_style(parts: var seq[string], last_style, style: Style, open_id: string = "") =
  var close_tags: seq[string]
  var i = last_style.path.len - 1
  while i >= 0:
    #echo &"i={i} drop {last_style.path[i].name}"
    if i >= style.path.len or last_style.path[i].name != style.path[i].name or not style.path[i].merge_previous:
      parts.add(["</", h(last_style.path[i].name), ">"])
      i = i - 1
    else:
      break
  i = i + 1
  while i < style.path.len:
    #echo &"i={i} add {style.path[i].name}"
    parts.add(["<", h(style.path[i].name)])
    if i == style.path.len - 1 and open_id != "":
      parts.add([" id=\"", open_id, "\""])
    if style.path[i].classes.len > 0:
      parts.add([" class=\"", h(style.path[i].classes.join(" ")), "\""])
    parts.add(">")
    i = i + 1

type AfterParagraphCallback = proc(p: Paragraph): string

proc to_html*(article: Article, after: AfterParagraphCallback = nil): string =
  var parts: seq[string] = @[]
  var style, last_style: Style
  for p in article.paragraphs:
    last_style = style
    style = p.style.parse_style()
    html_close_open_style(parts, last_style, style, "paragraph-" & p.guid)
    parts.add(h(p.text))
    if after != nil:
      parts.add(after(p))

  last_style = style
  style.path = @[]
  html_close_open_style(parts, last_style, style)

  result = parts.join("")

proc add_paragraphs_from_nodes(par: var seq[Paragraph], node: XmlNode, path: var seq[string]) =
  var last_text = false
  var first_child = true
  for child in items(node):
    if child.kind == xnElement:
      last_text = false
      var classes = child.attr("class").split(" ")
      while classes.len > 0 and classes[0] == "": classes.del(0)
      let item = (("+" & child.tag) & classes).join(".")
      var new_path = path & item
      par.add_paragraphs_from_nodes(child, new_path)
    elif child.kind == xnText or child.kind == xnCData or child.kind == xnEntity:
      if last_text:
        par[par.len-1].text.add(child.text)
      else:
        last_text = true
        par.add((id: 0, guid: "", style: path.join(" "), text: child.text))
    else:
      continue
    if first_child:
      var i = 0
      while i < path.len:
        if path[i].starts_with("+"):
          path[i] = "=" & path[i][1..^1]
        i = i + 1

proc from_html*(article: var Article, html_data: string) =
  article.paragraphs = @[]
  let html = html_data.parse_html()
  var path: seq[string] = @[]
  add_paragraphs_from_nodes(article.paragraphs, html, path)
