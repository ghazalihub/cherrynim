import cherrynim, asyncdispatch, tables

type GeneratorDemo = ref object of Controller

proc index*(g: GeneratorDemo): Future[string] {.async, gcsafe.} =
  return "Simulated yield"

proc main() =
  let root = GeneratorDemo()
  root.handlers = initTable[string, Handler]()
  root.exposeHandlers("index")
  quickstart(root)

if isMainModule: main()
