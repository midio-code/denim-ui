import sugar, options
import types, element_bounds_changed_event, element
import ../vec
import ../rect
import rx_nim

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

proc observeCenterRelativeTo*(self: Element, other: Element): Observable[Point] =
  self.observeWorldPosition().map(
    proc(p: Point): Point =
      if other.isNil:
        p
      elif self.bounds.isNone:
        p.relativeTo(other)
      else:
        p.relativeTo(other).add(self.bounds.get().size / 2.0))

proc observeCenter*(self: Element): Observable[Point] =
  self.observeWorldPosition().map(
    proc(p: Vec2[float]): Point =
      if self.bounds.isNone:
        return p
      p + self.bounds.get().size / 2.0
  )
