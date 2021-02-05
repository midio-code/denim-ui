import sugar
#import rx_nim

type
  EventHandler*[T] = (T) -> void
  EventEmitter*[T] = ref object
    listeners: seq[EventHandler[T]]
    toAdd*: seq[EventHandler[T]]
    toRemove: seq[EventHandler[T]]

proc emitter*[T](): EventEmitter[T] =
  EventEmitter[T](listeners: @[], toAdd: @[], toRemove: @[])

proc contains*[T](self: EventEmitter[T], listener: EventHandler[T]): bool =
  let hasInListeners = self.listeners.contains(listener)
  let willAdd = self.toAdd.contains(listener)
  let willRemove = self.toRemove.contains(listener)
  (hasInListeners and not(willRemove)) or willAdd

proc numListeners*[T](self: EventEmitter[T]): int =
  self.listeners.len() - self.toRemove.len() + self.toAdd.len()

proc emit*[T](self: var EventEmitter[T], data: T): void =
  for toRemove in self.toRemove:
    let index = self.listeners.find(toRemove)
    if index != -1:
      self.listeners.delete(index)
  self.toRemove = @[]

  for toAdd in self.toAdd:
    self.listeners.add(toAdd)
  self.toAdd = @[]

  for listener in self.listeners:
    listener(data)

proc add*[T](self: var EventEmitter[T], listener: EventHandler[T]): void =
  self.toAdd.add(listener)

proc remove*[T](self: var EventEmitter[T], listener: EventHandler[T]): void =
  self.toRemove.add(listener)

template createEvent*(name: untyped, T: typedesc): untyped =
  var emitter = emitter[T]()
  proc `on name`*(handler: (T) -> void): void =
    emitter.add(handler)
  proc `removeFrom name`*(handler: (T) -> void): void =
    emitter.remove(handler)
  proc `emit name`*(args: T): void =
    emitter.emit(args)
