## Logging module for CherryNim.
import times, strutils, os, asynchttpserver, tables
import ./core

type
  LogManager* = ref object
    accessFile*: string
    errorFile*: string
    screen*: bool

var log* {.threadvar.}: LogManager

proc time*(lm: LogManager): string =
  ## Returns the current time in Apache Common Log Format.
  let now = now()
  return now.format("dd/MMM/yyyy:HH:mm:ss")

proc error*(lm: LogManager, msg: string, context = "", severity = "INFO") =
  ## Logs an error message.
  if lm == nil: return
  let entry = lm.time() & " " & context & " " & severity & " " & msg
  if lm.screen:
    echo entry
  if lm.errorFile != "":
    let f = open(lm.errorFile, fmAppend)
    f.writeLine(entry)
    f.close()

proc logMsg*(lm: LogManager, msg: string, context = "", severity = "INFO") =
  ## Alias for error.
  lm.error(msg, context, severity)

proc access*(lm: LogManager) =
  ## Logs an access message in Apache/NCSA Combined Log format.
  if lm == nil or request == nil or response == nil: return

  let remote = request.headers.getOrDefault("X-Forwarded-For")
  let h = if remote == "": "127.0.0.1" else: remote
  let l = "-"
  let u = "-" # Could be request.login
  let t = lm.time()
  let r = request.reqMethod & " " & request.pathInfo & " " & request.queryString
  let s = response.status.split(' ')[0]
  let b = response.headers.getOrDefault("Content-Length")
  let f = request.headers.getOrDefault("Referer")
  let a = request.headers.getOrDefault("User-Agent")

  let entry = h & " " & l & " " & u & " [" & t & "] \"" & r & "\" " & s & " " & (if b == "": "-" else: b) & " \"" & f & "\" \"" & a & "\""

  if lm.screen:
    echo entry
  if lm.accessFile != "":
    let af = open(lm.accessFile, fmAppend)
    af.writeLine(entry)
    af.close()
