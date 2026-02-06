import cherrynim, asyncdispatch, os, tables

type FileDemo = ref object of Controller

proc index*(f: FileDemo): Future[string] {.async, gcsafe.} =
  return "Files"

proc upload*(f: FileDemo, myFile: string): Future[string] {.async, gcsafe.} =
  writeFile("uploaded.txt", myFile)
  return "Uploaded"

proc download*(f: FileDemo): Future[string] {.async, gcsafe.} =
  writeFile("demo.txt", "content")
  return serveFile("demo.txt")

proc main() =
  let root = FileDemo()
  root.handlers = initTable[string, Handler]()
  root.exposeHandlers("index", "upload", "download")
  quickstart(root)

if isMainModule: main()
