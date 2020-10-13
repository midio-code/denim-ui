import ../events
import sugar

var updateManagerListeners = emitter[float]()

proc addUpdateListenerIfNotPresent*(listener: EventHandler[float]): void =
  if not updateManagerListeners.contains(listener):
    updateManagerListeners.add(listener)

proc removeUpdateListener*(listener: EventHandler[float]): void =
  if updateManagerListeners.contains(listener):
    updateManagerListeners.remove(listener)

proc dispatchUpdate*(dt: float): void =
  updateManagerListeners.emit(dt)
