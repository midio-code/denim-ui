import sugar
import observables/observables

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
    self.listeners.delete(self.listeners.find(toRemove))
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

proc toObservable*[T](emitter: var EventEmitter[T]): Observable[T] =
  let subj = subject[T]()
  emitter.add(
    proc(newVal: T): void =
      subj.next(newVal)
  )
  subj.source

template createEvent*(name: untyped, T: typedesc): untyped =
  var emitter = emitter[T]()
  proc `on name`*(handler: (T) -> void): void =
    emitter.add(handler)
  proc `emit name`*(args: T): void =
    emitter.emit(args)
  proc `observe name`*(): Observable[T] =
    emitter.toObservable()
