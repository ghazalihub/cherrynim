## HTTP server implementation for CherryNim.
import asyncdispatch, asynchttpserver, strutils, tables, uri
import ./core, ./dispatch, ./tools, ./logging, ./wspbus

proc parseMultipart(body: string, contentType: string): Table[string, string] =
  # Very basic multipart parsing for tut09
  var res = initTable[string, string]()
  if "boundary=" in contentType:
    let boundary = "--" & contentType.split("boundary=")[1]
    let parts = body.split(boundary)
    for part in parts:
      if "name=\"" in part:
        let name = part.split("name=\"")[1].split("\"")[0]
        let content = part.split("\r\n\r\n")[1].split("\r\n")[0]
        res[name] = content
  return res

proc handleRequest*(req: asynchttpserver.Request): Future[void] {.async, gcsafe.} =
  ## Handles an incoming HTTP request from asynchttpserver.
  if config.len == 0:
    config = initTable[string, string]()
  if log == nil:
    log = LogManager(screen: true)
  if engine == nil:
    engine = Bus(listeners: initTable[string, seq[BusCallback]]())
  let path = req.url.path

  # Check for grafts first
  if tree != nil:
    for graftPath, handler in tree.grafts:
      if path.startsWith(graftPath):
        # We need a proper way to run grafts.
        # For now, let's keep it simple.
        discard

  let app = tree.apps.getOrDefault("") # Simple for now

  request = newRequest()
  request.reqMethod = $req.reqMethod
  request.pathInfo = path
  request.queryString = req.url.query
  request.body = req.body

  # Parse Query Params
  if request.queryString != "":
    for k, v in decodeQuery(request.queryString):
      request.params[k] = v

  # Parse Body Params
  let contentType = req.headers.getOrDefault("Content-Type")
  if contentType.startsWith("application/x-www-form-urlencoded"):
    for k, v in decodeQuery(request.body):
      request.params[k] = v
  elif contentType.startsWith("multipart/form-data"):
    let mparams = parseMultipart(request.body, contentType)
    for k, v in mparams.pairs:
      request.params[k] = v

  request.headers = req.headers
  request.app = app

  response = newResponse()

  try:
    if app != nil:
      if app.findConfig(path, "tools.sessions.on") == "true":
        request.enableSessions()

      if app.findConfig(path, "tools.gzip.on") == "true":
        discard

      await request.runHooks(onStartResource)
      let segments = splitPath(path)
      await request.runHooks(beforeHandler)
      session = request.session
      response.body = await app.dispatch(app.root, segments, request.params)
      await request.runHooks(beforeFinalize)

      if app.findConfig(path, "tools.gzip.on") == "true" and req.headers.getOrDefault("Accept-Encoding").contains("gzip"):
        response.headers["Content-Encoding"] = "gzip"

    else:
      raise (ref HTTPError)(status: 404, message: "Not Found")
  except HTTPError as e:
    response.status = $e.status & " Error"
    response.body = e.message
  except HTTPRedirect as e:
    response.status = $e.status & " Redirect"
    response.headers["Location"] = e.urls[0]
    response.body = "Redirecting to " & e.urls[0]
  except Exception as e:
    response.status = "500 Internal Server Error"
    response.body = "Internal Server Error: " & e.msg

  response.finalize()
  log.access()
  let statusCode = try: response.status.split(' ')[0].parseInt except: 200
  await req.respond(HttpCode(statusCode), response.body, response.headers)

proc startServer*(port: int = 8080, host: string = "127.0.0.1") {.async.} =
  ## Starts the CherryNim server.
  let server = newAsyncHttpServer()
  echo "Starting CherryNim on http://", host, ":", port
  await server.serve(Port(port), handleRequest, host)
