## Publish/Subscribe bus for CherryNim.
import asyncdispatch, tables, sequtils

type
  BusCallback* = proc (args: seq[string]) {.async, gcsafe.}

  Bus* = ref object
    listeners*: Table[string, seq[BusCallback]]

var engine* = Bus(listeners: initTable[string, seq[BusCallback]]())

proc subscribe*(bus: Bus, channel: string, callback: BusCallback) =
  ## Subscribes a callback to a channel.
  if not bus.listeners.contains(channel):
    bus.listeners[channel] = @[]
  bus.listeners[channel].add(callback)

proc publish*(bus: Bus, channel: string, args: seq[string] = @[]) {.async.} =
  ## Publishes a message to a channel.
  if bus.listeners.contains(channel):
    for callback in bus.listeners[channel]:
      await callback(args)

proc start*(bus: Bus) {.async.} =
  ## Signals the bus that the engine is starting.
  await bus.publish("start")

proc stop*(bus: Bus) {.async.} =
  ## Signals the bus that the engine is stopping.
  await bus.publish("stop")
