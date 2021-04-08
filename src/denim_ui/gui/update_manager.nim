import ../events
import sugar

var updateManagerListeners = emitter[float]()

proc addUpdateListenerIfNotPresent*(listener: EventHandler[float]): void =
  if not updateManagerListeners.contains(listener):
    updateManagerListeners.add(listener)

proc removeUpdateListener*(listener: EventHandler[float]): void =
  if updateManagerListeners.contains(listener):
    updateManagerListeners.remove(listener)

var time = 0.0

type
  Waiter = object
    callback: () -> void
    startedAt: float
    waitingFor: float

  Dispose* = () -> void

var waiters: seq[Waiter] = @[]

proc wait*(callback: () -> void, waitFor: float): Dispose =
  ## Calls `callback` after `waitFor` ms
  let w =
    Waiter(
      callback: callback,
      startedAt: time,
      waitingFor: waitFor
    )
  waiters.add(w)
  result = proc(): void =
    let i = waiters.find(w)
    if i >= 0:
      waiters.delete(i)

proc dispatchUpdate*(dt: float): void =
  time += dt
  updateManagerListeners.emit(dt)

  var toRemove: seq[int] = @[]
  for i, w in waiters.pairs():
    if time >= w.startedAt + w.waitingFor:
      w.callback()
      toRemove.add(i)
  for i in toRemove:
    waiters.delete(i)
