## Process plugins for CherryNim.
import os, times, asyncdispatch, tables
import ./core, ./wspbus, ./logging

type
  Autoreloader* = ref object
    files*: seq[string]
    mtimes*: Table[string, float]
    frequency*: int

proc newAutoreloader*(files: seq[string] = @[], frequency: int = 1): Autoreloader =
  Autoreloader(files: files, mtimes: initTable[string, float](), frequency: frequency)

proc run*(ar: Autoreloader) {.async, gcsafe.} =
  ## Polls files for changes and restarts if necessary.
  for f in ar.files:
    if fileExists(f):
      let mtime = getLastModificationTime(f).toUnixFloat()
      if not ar.mtimes.contains(f):
        ar.mtimes[f] = mtime
      elif mtime > ar.mtimes[f]:
        log.error("Restarting because " & f & " changed.")
        await stop(wspbus.engine)
        quit(0)

proc subscribe*(ar: Autoreloader) =
  wspbus.engine.subscribe("start", proc(args: seq[string]) {.async, gcsafe.} =
    while true:
      await ar.run()
      await sleepAsync(ar.frequency * 1000)
  )

# Signal handling in Nim is tricky with async.
when defined(posix):
  import posix
  proc handleSignal(sig: cint) {.noconv.} =
    # Just quit for now
    quit(0)

  proc setupSignals*() =
    var sa: Sigaction
    sa.sa_handler = handleSignal
    discard sigaction(SIGINT, sa)
    discard sigaction(SIGTERM, sa)
else:
  proc setupSignals*() = discard
