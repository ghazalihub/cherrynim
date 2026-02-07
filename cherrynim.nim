import tables, asyncdispatch, macros
import cherrynim/core, cherrynim/server, cherrynim/dispatch, cherrynim/tools, cherrynim/wspbus, cherrynim/logging, cherrynim/plugins
export core, server, dispatch, tools, wspbus, logging, plugins

macro mount*(root: Controller, scriptName: string = "", config: untyped = nil): untyped =
  ## Macro that mounts an application and generates its dispatch function based on its concrete type.
  result = quote do:
    if engine == nil: engine = Bus(listeners: initTable[string, seq[BusCallback]]())
    if tree == nil:
      tree = Tree(apps: initTable[string, Application](), grafts: initTable[string, proc (req: Request): Future[Response] {.async, gcsafe.}]())

    let actualRoot = `root`

    # Handle config at runtime to avoid macro issues
    var finalConfig: Table[string, Table[string, string]]
    when `config` is string:
      finalConfig = loadConfigFromFile(`config`)
    elif `config` is Table[string, Table[string, string]]:
      finalConfig = `config`
    else:
      finalConfig = initTable[string, Table[string, string]]()

    let app = Application(root: actualRoot, scriptName: `scriptName`, config: finalConfig)
    app.dispatch = proc (c: Controller, s: seq[string], p: Table[string, string]): Future[string] {.async, gcsafe.} =
      let typedRoot = cast[typeof(actualRoot)](c)
      return await dispatch(typedRoot, s, p)

    app.checkConfig()
    tree.apps[`scriptName`] = app
    app

macro quickstart*(root: Controller, config: untyped = nil): untyped =
  ## Macro that mounts the root application and starts the server.
  result = quote do:
    if engine == nil: engine = Bus(listeners: initTable[string, seq[BusCallback]]())
    setupSignals()
    discard mount(`root`, "", `config`)
    waitFor start(engine)
    waitFor startServer()
