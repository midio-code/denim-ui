import ../events
import sugar
import sequtils

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


var actionsToPerformNextFrame: seq[() -> void] = @[]
proc performNextFrame*(handler: () -> void): void =
  actionsToPerformNextFrame.add(handler)

proc dispatchNextFrameActions*(): void =
  ## Calls the actions that were scheduled last frame. This function should be called right after
  ## layout  has been calculated and world positions cache has been updated.
  # NOTE: Copying here in case `actionsToPerformNextFrame` is changed
  # by any of these actions
  let actionsToPerformThisFrame = actionsToPerformNextFrame
  actionsToPerformNextFrame = @[]
  for action in actionsToPerformThisFrame:
    action()

proc dispatchUpdate*(dt: float): void =
  time += dt
  updateManagerListeners.emit(dt)

  var toRemove: seq[int] = @[]
  let items = toSeq(waiters.pairs())
  for item in items:
    let (i, w) = item
    if time >= w.startedAt + w.waitingFor:
      w.callback()
      toRemove.add(i)
  for i in toRemove:
    waiters.delete(i)
