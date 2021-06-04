import sugar, options
import types, element_bounds_changed_event, element
import ../vec
import ../rect
import world_position
import rx_nim

proc observeBounds*(e: Element): Observable[Rect[float]] =
  let state = behaviorSubject(e.bounds.get(rect(0.0)))
  var prevBounds: Bounds
  e.onBoundsChanged(
    proc(newBounds: Rect[float]): void =
      if isNil(prevBounds) or prevBounds != newBounds:
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

type
  Side* {.pure.} = enum
    Left, TopLeft, Top, TopRight, Right, BottomRight, Bottom, BottomLeft, Center
  Vertical {.pure.} = enum
    Top, Center, Bottom
  Horizontal {.pure.} = enum
    Left, Center, Right

proc verticalComponent(side: Side): Vertical =
  case side:
    of Side.TopLeft, Side.TopRight, Side.Top: Vertical.Top
    of Side.Left, Side.Center, Side.Right: Vertical.Center
    of Side.BottomLeft, Side.BottomRight, Side.Bottom: Vertical.Bottom

proc horizontalComponent(side: Side): Horizontal =
  case side:
    of Side.BottomLeft, Side.TopLeft, Side.Left: Horizontal.Left
    of Side.Top, Side.Center, Side.Bottom: Horizontal.Center
    of Side.TopRight, Side.BottomRight, Side.Right: Horizontal.Right

proc mapPointToSide(point: Point, bounds: Bounds, side: Side): Point =
  let size = bounds.size
  let xOffset = case side.horizontalComponent:
    of Horizontal.Left: 0.0
    of Horizontal.Center: size.x / 2.0
    of Horizontal.Right: size.x
  let yOffset = case side.verticalComponent:
    of Vertical.Top: 0.0
    of Vertical.Center: size.y / 2.0
    of Vertical.Bottom: size.y
  point + vec2(xOffset, yOffset)

proc observeSide*(self: Element, side: Side): Observable[Point] =
  self.observeWorldPosition().map(
    proc(p: Vec2[float]): Point =
      if self.bounds.isNone:
        return p
      p.mapPointToSide(self.bounds.get(), side)
  )

proc observeSideRelativeTo*(self: Element, side: Side, other: Element): Observable[Point] =
  if isNil(other):
    raise newException(Exception, "Tried to observe side of an Element that was nil")
  self.observeWorldPosition()
    .combineLatest(
      self.observeBounds(),
      proc(p: Point, bounds: Bounds): Point =
        p.relativeTo(other).mapPointToSide(bounds, side)
    )

proc observeHalfWidth*(self: Element): Observable[float] =
  self.observeBounds().map((b: Bounds) => b.size.x / 2.0)


proc observeSize*(self: Element): Observable[Vec2[float]] =
  self.observeBounds().map((b: Bounds) => b.size)

proc observeWidth*(self: Element): Observable[float] =
  self.observeBounds().map((b: Bounds) => b.size.x)

proc observeHeight*(self: Element): Observable[float] =
  self.observeBounds().map((b: Bounds) => b.size.y)
