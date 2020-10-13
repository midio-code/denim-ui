import tables, options
import types
import element
import ../events
import ../observables/observables
import ../vec
import ../rect

proc observeWorldPosition*(self: Element): Observable[Vec2[float]] =
  var prevPos = self.actualWorldPosition()
  let state = behaviorSubject[Vec2[float]](prevPos)
  onLayoutPerformed(
    proc(newVal: Rect[float]): void =
      let currentPos = self.actualWorldPosition()
      if currentPos != prevPos:
        prevPos = currentPos
        state.next(currentPos)
  )
  state.source
