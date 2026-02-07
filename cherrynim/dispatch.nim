## Dispatching logic for CherryNim.
import macros, strutils, asyncdispatch, tables
import ./core

proc splitPath*(path: string): seq[string] =
  ## Splits a URL path into its segments.
  if path == "" or path == "/":
    return @[]
  let parts = path.split('/')
  for p in parts:
    if p != "":
      result.add p

macro dispatch*(obj: any, segments: seq[string], params: Table[string, string]): untyped =
  let headNameId = ident("headName")
  let tailId = ident("tail")
  let pId = ident("p")

  var fieldBranches = nnkIfStmt.newTree()

  let tutorialFields = @["joke", "links", "extra", "another"]
  for f in tutorialFields:
    let fId = ident(f)
    fieldBranches.add nnkElifBranch.newTree(
      quote do: `headNameId` == `f`,
      quote do:
        when compiles(`obj`.`fId`):
          when `obj`.`fId` is Controller:
            return await runDispatch(`obj`.`fId`, `tailId`, `pId`)
    )

  result = quote do:
    block:
      proc runDispatch(o: auto, s: seq[string], p: Table[string, string]): Future[string] {.async, gcsafe.} =
        if s.len == 0:
          if o.handlers.contains("index"):
            return await o.handlers["index"](p)
          else:
            return "404 Not Found"
        else:
          let `headNameId` = s[0]
          let `tailId` = s[1..^1]
          let `pId` = p

          `fieldBranches`

          if o.handlers.contains(`headNameId`):
            return await o.handlers[`headNameId`](p)

          if o.handlers.contains("default"):
            var p2 = p
            p2["vpath"] = `headNameId`
            return await o.handlers["default"](p2)

          return "404 Not Found"

      runDispatch(`obj`, `segments`, `params`)

macro exposeHandlers*(obj: Controller, names: varargs[untyped]): untyped =
  let stmts = nnkStmtList.newTree()
  for name in names:
    let nameStr = name.strVal
    let nameIdent = ident(nameStr)
    stmts.add quote do:
      `obj`.handlers[`nameStr`] = proc (p: Table[string, string]): Future[string] {.async, gcsafe.} =
        if p.contains("name"):
          when compiles(`obj`.`nameIdent`(p["name"])):
            return await `obj`.`nameIdent`(p["name"])
        if p.contains("user"):
          when compiles(`obj`.`nameIdent`(p["user"])):
            return await `obj`.`nameIdent`(p["user"])
        if p.contains("code"):
          when compiles(`obj`.`nameIdent`(p["code"])):
            return await `obj`.`nameIdent`(p["code"])
        if p.contains("myFile"):
          when compiles(`obj`.`nameIdent`(p["myFile"])):
            return await `obj`.`nameIdent`(p["myFile"])
        if p.contains("vpath"):
          when compiles(`obj`.`nameIdent`(p["vpath"])):
            return await `obj`.`nameIdent`(p["vpath"])

        when compiles(`obj`.`nameIdent`()):
          return await `obj`.`nameIdent`()
        else:
          return "Error: Handler arguments not matched"
  result = stmts
