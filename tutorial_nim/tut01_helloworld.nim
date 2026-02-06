import cherrynim, asyncdispatch, tables

type HelloWorld = ref object of Controller

proc index*(h: HelloWorld): Future[string] {.async, gcsafe.} =
  return "Hello World!"

proc main() =
  let root = HelloWorld()
  root.handlers = initTable[string, Handler]()
  root.exposeHandlers("index")
  quickstart(root)

if isMainModule: main()
