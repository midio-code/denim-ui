import tables, options
import types
import element
import ../events
import rx_nim
import ../vec
import ../rect
import element_bounds_changed_event

proc observeWorldPosition*(self: Element): Observable[Vec2[float]] =
  var prevPos = self.actualWorldPosition()
  let state = behaviorSubject[Vec2[float]](prevPos)
  onBeforeLayout(
    proc(newVal: Rect[float]): void =
      let currentPos = self.actualWorldPosition()
      if currentPos != prevPos:
        prevPos = currentPos
        state.next(currentPos)
  )
  state.source
