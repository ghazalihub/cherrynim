import cherrynim, asyncdispatch, strutils, tables

type HTTPErrorDemo = ref object of Controller

proc index*(h: HTTPErrorDemo): Future[string] {.async, gcsafe.} =
  return "Errors"

proc error*(h: HTTPErrorDemo, code: string): Future[string] {.async, gcsafe.} =
  raise (ref HTTPError)(status: code.parseInt, message: "Explicit")

proc main() =
  let root = HTTPErrorDemo()
  root.handlers = initTable[string, Handler]()
  root.exposeHandlers("index", "error")
  quickstart(root)

if isMainModule: main()
