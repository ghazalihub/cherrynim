import cherrynim, asyncdispatch, tables, strutils

type HitCounter = ref object of Controller

proc index*(h: HitCounter): Future[string] {.async, gcsafe.} =
  let count = try: session.getOrDefault("count", "0").parseInt except: 0
  let newCount = count + 1
  session["count"] = $newCount
  return "Count: " & $newCount

proc main() =
  let root = HitCounter()
  root.handlers = initTable[string, Handler]()
  root.exposeHandlers("index")
  config["tools.sessions.on"] = "true"
  quickstart(root)

if isMainModule: main()
