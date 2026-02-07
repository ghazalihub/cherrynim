import cherrynim, asyncdispatch, tables

type HelloWorld = ref object of Controller

proc index*(h: HelloWorld): Future[string] {.async, gcsafe.} =
  return "Index. <a href=\"show_msg\">Msg</a>"

proc show_msg*(h: HelloWorld): Future[string] {.async, gcsafe.} =
  return "Hello world!"

proc main() =
  let root = HelloWorld()
  root.handlers = initTable[string, Handler]()
  root.exposeHandlers("index", "show_msg")
  quickstart(root)

if isMainModule: main()
