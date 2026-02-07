## Built-in tools and helpers for CherryNim.
import asyncdispatch, tables, strutils, os, json, asynchttpserver, times, mimetypes, base64, random
import ./core

var mimes {.threadvar.}: MimeDB
var mimesInitialized {.threadvar.}: bool

# 1. Logger Tool
proc loggerTool*() {.async, gcsafe.} =
  ## Simple tool that logs request processing with timestamp.
  echo "Processing request: ", now().format("yyyy-MM-dd HH:mm:ss")

# 2. Static Tools
proc staticfileTool*(req: core.Request, res: core.Response, filename: string) {.async, gcsafe.} =
  ## Tool for serving a specific static file. Handles path normalization and mimetype detection.
  if not mimesInitialized:
    mimes = newMimetypes()
    mimesInitialized = true

  let normalized = filename.expandFilename()
  if fileExists(normalized):
    res.body = readFile(normalized)
    let ext = normalized.splitFile().ext
    res.headers["Content-Type"] = mimes.getMimetype(ext.strip(chars = {'.'}))
  else:
    raise (ref HTTPError)(status: 404, message: "File not found")

proc staticdirTool*(req: core.Request, res: core.Response, dir: string) {.async, gcsafe.} =
  ## Tool for serving static files from a directory.
  ## Prevents directory traversal by validating that the final path is within the base directory.
  let appPath = req.app.scriptName
  var relPath = req.pathInfo
  if relPath.startsWith(appPath):
    relPath = relPath[appPath.len..^1]
  relPath = relPath.strip(chars = {'/'})

  let baseDir = dir.expandFilename()
  let fullPath = (baseDir / relPath).expandFilename()

  if fullPath.startsWith(baseDir) and fileExists(fullPath):
    await staticfileTool(req, res, fullPath)
  else:
    # If not found, we don't raise here to allow other handlers/default to catch it if applicable
    discard

# 3. Session Tool
var sessions* {.threadvar.}: Table[string, Table[string, string]]
  ## Memory-based session storage. Keyed by session ID.

proc sessionsTool*(req: core.Request) {.async, gcsafe.} =
  ## Tool that manages user sessions via cookies.
  ## Generates a new session ID if one isn't present or valid.
  let cookies = req.headers.getOrDefault("Cookie")
  var sid = ""
  if cookies != "":
    for part in cookies.split(';'):
      let kv = part.strip().split('=')
      if kv.len == 2 and kv[0].strip() == "session_id":
        sid = kv[1].strip()

  if sessions.len == 0:
    sessions = initTable[string, Table[string, string]]()

  if sid == "" or not sessions.contains(sid):
    randomize()
    sid = "sid_" & $(now().toTime().toUnix()) & "_" & $rand(1000000000)
    sessions[sid] = initTable[string, string]()

  req.session = sessions[sid]
  req.params["session_id"] = sid

# 4. Auth Tools
proc basicAuthTool*(req: core.Request, users: Table[string, string]) {.async, gcsafe.} =
  ## Tool for basic HTTP authentication. Checks 'Authorization' header against a table of users.
  let authHeader = req.headers.getOrDefault("Authorization")
  var authorized = false
  if authHeader.startsWith("Basic "):
    let encoded = authHeader[6..^1]
    let decoded = decode(encoded)
    let parts = decoded.split(':', 1)
    if parts.len == 2:
      let user = parts[0]
      let password = parts[1]
      if users.getOrDefault(user) == password:
        authorized = true

  if not authorized:
    raise (ref HTTPError)(status: 401, message: "Unauthorized")

# 5. Caching Tool
var cache* {.threadvar.}: Table[string, string]
  ## Simple memory-based cache.

proc cachingTool*(req: core.Request, res: core.Response) {.async, gcsafe.} =
  ## Tool that serves cached responses for GET requests.
  if cache.len == 0: cache = initTable[string, string]()
  if req.reqMethod == "GET" and cache.contains(req.pathInfo):
    res.body = cache[req.pathInfo]

# 6. Encoding Tool
proc encodingTool*(res: core.Response, charset: string = "utf-8") {.async, gcsafe.} =
  ## Tool that ensures the response has the correct charset in the Content-Type header.
  if not res.headers.getOrDefault("Content-Type").contains("charset="):
    res.headers["Content-Type"] = res.headers.getOrDefault("Content-Type") & "; charset=" & charset

# 7. JSON Tools
proc jsonInTool*(req: core.Request, body: string) {.async, gcsafe.} =
  ## Tool that parses JSON request body into request params.
  try:
    let node = parseJson(body)
    for k, v in node.getFields():
      req.params[k] = v.getStr()
  except:
    discard

proc jsonOutTool*(res: core.Response) {.async, gcsafe.} =
  ## Tool that sets the content-type for JSON responses.
  res.headers["Content-Type"] = "application/json"

# 8. Proxy Tool
proc proxyTool*(req: core.Request) {.async, gcsafe.} =
  ## Tool that handles X-Forwarded-For and X-Forwarded-Host headers.
  let forwardedHost = req.headers.getOrDefault("X-Forwarded-Host")
  if forwardedHost != "":
    req.headers["Host"] = forwardedHost

# 9. Referer Tool
proc refererTool*(req: core.Request, accepted: seq[string]) {.async, gcsafe.} =
  ## Tool that checks the Referer header against a list of accepted domains.
  let referer = req.headers.getOrDefault("Referer")
  if referer == "": return
  var matches = false
  for acc in accepted:
    if acc in referer:
      matches = true
      break
  if not matches:
    raise (ref HTTPError)(status: 403, message: "Forbidden Referer")

# 10. ETags Tool
import md5
proc etagsTool*(req: core.Request, res: core.Response) {.async, gcsafe.} =
  ## Tool that handles ETags by hashing the response body.
  if res.body == "": return
  let etag = getMD5(res.body)
  res.headers["ETag"] = etag
  if req.headers.getOrDefault("If-None-Match") == etag:
    res.status = "304 Not Modified"
    res.body = ""

# Helpers to enable tools
proc enableSessions*(req: core.Request) =
  ## Registers the session tool to run before the handler.
  req.hooks[beforeHandler].add(Hook(callback: (proc() {.async, gcsafe.} = await sessionsTool(req)), priority: 50))

proc enableStaticDir*(req: core.Request, res: core.Response, dir: string) =
  ## Registers the static directory tool to run before the handler.
  req.hooks[beforeHandler].add(Hook(callback: (proc() {.async, gcsafe.} = await staticdirTool(req, res, dir)), priority: 50))

proc serveFile*(path: string, contentType: string = "", disposition: string = "", name: string = ""): string =
  ## Helper to serve a file's content as a string.
  if fileExists(path):
    return readFile(path)
  return "File not found: " & path
