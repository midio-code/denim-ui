import sequtils
import drawing_primitives
import element
import strformat
import options
import ../rect

var debugDrawings: seq[Primitive] = @[]

template debugDraw(primitive: Primitive): void =
  debugDrawings.add(primitive)

proc debugDrawRect*(rect: Rect[float]): void =
  echo "Drawing debug rect: ", rect
  if not isNil rect:
    debugDraw(rectangle(bounds = rect, strokeInfo = some(StrokeInfo(width: 2.0)), colorInfo = some(ColorInfo(stroke: some("magenta")))))

proc flushDebugDrawings*(): seq[Primitive] =
  result = debugDrawings
  debugDrawings = @[]
