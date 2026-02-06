import cherrynim, asyncdispatch, tables

type
  Page = ref object of Controller
    title*: string

proc index*(h: Page): Future[string] {.async, gcsafe.} =
  return h.title

type
  AnotherPage = ref object of Page
  HomePage = ref object of Page
    another*: AnotherPage

proc main() =
  let another = AnotherPage(title: "Another")
  another.handlers = initTable[string, Handler]()
  another.exposeHandlers("index")

  let root = HomePage(title: "Home", another: another)
  root.handlers = initTable[string, Handler]()
  root.exposeHandlers("index")
  quickstart(root)

if isMainModule: main()
