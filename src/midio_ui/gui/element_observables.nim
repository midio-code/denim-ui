import sugar, options
import types, element_bounds_changed_event
import ../rect
import ../observables

proc observeBounds*(e: Element): Observable[Rect[float]] =
  let state = behaviorSubject(e.bounds.get(rect(0.0)))
  var prevBounds = e.bounds.get(rect(0.0))
  e.onBoundsChanged(
    proc(newBounds: Rect[float]): void =
      if prevBounds != newBounds:
        prevBounds = newBounds
        state.next(newBounds)
  )
  state.source
