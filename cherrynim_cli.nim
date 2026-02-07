## CLI tool for CherryNim.
import os, strutils

proc createScaffold(name: string) =
  let baseDir = name
  createDir(baseDir)
  createDir(baseDir / "cherrynim")
  createDir(baseDir / "static")
  createDir(baseDir / "templates")

  writeFile(baseDir / "app.nim", """
import cherrynim, asyncdispatch, tables

type Root = ref object of Controller

method index*(h: Root): Future[string] {.async, base, gcsafe.} =
  return "Welcome to your new CherryNim app!"

proc main() =
  let root = Root()
  root.handlers = initTable[string, Handler]()
  root.exposeHandlers("index")
  quickstart(root)

if isMainModule: main()
""")

  echo "Created new CherryNim project: ", name

if isMainModule:
  let args = commandLineParams()
  if args.len > 1 and args[0] == "create":
    createScaffold(args[1])
  else:
    echo "Usage: cherrynim create <project_name>"
