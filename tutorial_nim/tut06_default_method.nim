import cherrynim, asyncdispatch, tables

type UsersPage = ref object of Controller

proc index*(u: UsersPage): Future[string] {.async, gcsafe.} =
  return "User list"

proc default*(u: UsersPage, user: string): Future[string] {.async, gcsafe.} =
  return "User: " & user

proc main() =
  let root = UsersPage()
  root.handlers = initTable[string, Handler]()
  root.exposeHandlers("index", "default")
  quickstart(root)

if isMainModule: main()
