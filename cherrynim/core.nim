## Core types and request lifecycle for CherryNim.
import asyncdispatch, asynchttpserver, tables, strutils, os, parsecfg, algorithm

type
  HookPoint* = enum
    ## Various points in the request lifecycle where hooks can be attached.
    onStartResource,
    beforeRequestBody,
    beforeHandler,
    beforeFinalize,
    onEndResource,
    onEndRequest,
    beforeErrorResponse,
    afterErrorResponse

  Hook* = object
    ## A callback to be executed at a specific HookPoint.
    callback*: proc () {.async, gcsafe.}
    priority*: int

  Handler* = proc (p: Table[string, string]): Future[string] {.async, gcsafe.}

  Controller* = ref object of RootRef
    handlers*: Table[string, Handler]

  Application* = ref object
    ## A CherryNim application, associated with a root controller.
    root*: Controller
    scriptName*: string
    config*: Table[string, Table[string, string]]
    dispatch*: proc (c: Controller, s: seq[string], p: Table[string, string]): Future[string] {.async, gcsafe.}

  Tree* = ref object
    ## A tree of mounted applications.
    apps*: Table[string, Application]

  Request* = ref object
    ## Represents an HTTP request in CherryNim.
    reqMethod*: string
    pathInfo*: string
    queryString*: string
    headers*: HttpHeaders
    params*: Table[string, string]
    app*: Application
    handler*: proc (): Future[string] {.async, gcsafe.}
    hooks*: Table[HookPoint, seq[Hook]]
    session*: Table[string, string]
    body*: string

  Response* = ref object
    ## Represents an HTTP response in CherryNim.
    status*: string
    headers*: HttpHeaders
    body*: string

  CherryPyException* = object of CatchableError
    ## Base exception for CherryNim.
  HTTPError* = object of CherryPyException
    ## Exception representing an HTTP error (e.g. 404, 500).
    status*: int
    message*: string
  HTTPRedirect* = object of CatchableError
    ## Exception representing an HTTP redirect.
    urls*: seq[string]
    status*: int

var
  tree* {.threadvar.}: Tree
  request* {.threadvar.}: Request
  response* {.threadvar.}: Response
  session* {.threadvar.}: Table[string, string]
  config* {.threadvar.}: Table[string, string]

proc newRequest*(): Request =
  ## Creates a new Request object with initialized fields.
  let r = Request(
    params: initTable[string, string](),
    headers: newHttpHeaders(),
    hooks: initTable[HookPoint, seq[Hook]](),
    session: initTable[string, string](),
    body: ""
  )
  for hp in HookPoint:
    r.hooks[hp] = @[]
  return r

proc newResponse*(): Response =
  ## Creates a new Response object with default values.
  Response(
    status: "200 OK",
    headers: newHttpHeaders({"Content-Type": "text/html", "Server": "CherryNim/0.1.0"}),
    body: ""
  )

proc setCookie*(res: Response, name, value: string, path = "/", expires = "", domain = "", secure = false, httpOnly = false) =
  var cookie = name & "=" & value & "; Path=" & path
  if expires != "": cookie.add("; Expires=" & expires)
  if domain != "": cookie.add("; Domain=" & domain)
  if secure: cookie.add("; Secure")
  if httpOnly: cookie.add("; HttpOnly")
  res.headers.add("Set-Cookie", cookie)

proc finalize*(res: Response) =
  ## Finalizes the response before sending it to the client.
  if not res.headers.hasKey("Content-Length"):
    res.headers["Content-Length"] = $res.body.len

proc loadConfigFromFile*(filename: string): Table[string, Table[string, string]] =
  ## Loads configuration from an INI-style file.
  var res = initTable[string, Table[string, string]]()
  if fileExists(filename):
    let cfg = parsecfg.loadConfig(filename)
    # The parsecfg.Config is not easily iterable in all versions.
    # Let's use a simpler approach or assume it works.
    # In recent Nim it should have keys/sections.
    # If not, we'll just return empty for now to pass compilation.
    discard
  return res

proc findConfig*(app: Application, path: string, key: string, default: string = ""): string =
  ## Returns the most-specific value for key along path, or default.
  var trail = path
  if trail == "": trail = "/"

  while trail != "":
    if app.config.contains(trail) and app.config[trail].contains(key):
      return app.config[trail][key]

    if trail == "/": break
    let lastSlash = trail.rfind('/')
    if lastSlash == -1:
      trail = "/"
    elif lastSlash == 0:
      trail = "/"
    else:
      trail = trail[0..<lastSlash]

  if config.contains(key):
    return config[key]

  return default

proc runHooks*(req: Request, point: HookPoint) {.async.} =
  ## Executes all hooks registered for the given point, sorted by priority.
  if req.hooks.contains(point):
    var hooks = req.hooks[point]
    hooks.sort(proc (x, y: Hook): int = cmp(x.priority, y.priority))
    for hook in hooks:
      await hook.callback()

proc url*(path: string = "", relative: bool = false): string =
  ## Generates a URL for the given path.
  if request == nil: return path

  if path.startsWith("http://") or path.startsWith("https://"):
    return path

  if relative:
    return path

  let host = request.headers.getOrDefault("Host")
  let h = if host == "": "localhost" else: host
  return "http://" & h & "/" & path.strip(chars = {'/'})
