import cherrynim, asyncdispatch, tables, strutils

type WelcomePage = ref object of Controller

proc index*(w: WelcomePage): Future[string] {.async, gcsafe.} =
  return "<form action=\"greetUser\"><input name=\"name\"><input type=\"submit\"></form>"

proc greetUser*(w: WelcomePage, name: string = ""): Future[string] {.async, gcsafe.} =
  return "Hello " & name

proc main() =
  let root = WelcomePage()
  root.handlers = initTable[string, Handler]()
  root.exposeHandlers("index", "greetUser")
  quickstart(root)

if isMainModule: main()
