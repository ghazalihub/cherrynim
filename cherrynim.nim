## CherryNim: A completely complete Nim port of CherryPy.
##
## CherryNim follows the same philosophy as CherryPy, providing a
## pythonic (nim-ic), object-oriented approach to web development.
import tables, asyncdispatch, macros
import cherrynim/core, cherrynim/server, cherrynim/dispatch, cherrynim/tools, cherrynim/wspbus, cherrynim/logging, cherrynim/plugins
export core, server, dispatch, tools, wspbus, logging, plugins

macro mount*(root: Controller, scriptName: string = "", config: any = initTable[string, Table[string, string]]()): untyped =
  ## Macro that mounts an application and generates its dispatch function based on its concrete type.
  result = quote do:
    if engine == nil: engine = Bus(listeners: initTable[string, seq[BusCallback]]())
    if tree == nil:
      tree = Tree(apps: initTable[string, Application]())

    let actualRoot = `root`
    let conf = when `config` is string: loadConfigFromFile(`config`) else: `config`
    let app = Application(root: actualRoot, scriptName: `scriptName`, config: conf)
    app.dispatch = proc (c: Controller, s: seq[string], p: Table[string, string]): Future[string] {.async, gcsafe.} =
      # Cast back to concrete type for the macro to work
      let typedRoot = cast[typeof(actualRoot)](c)
      return await dispatch(typedRoot, s, p)

    app.checkConfig()
    tree.apps[`scriptName`] = app
    app

macro quickstart*(root: Controller, config: any = initTable[string, Table[string, string]]()): untyped =
  ## Macro that mounts the root application and starts the server.
  result = quote do:
    if engine == nil: engine = Bus(listeners: initTable[string, seq[BusCallback]]())
    setupSignals()
    discard mount(`root`, "", `config`)
    waitFor start(engine)
    waitFor startServer()
