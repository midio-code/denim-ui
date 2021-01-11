import sequtils
import drawing_primitives
import element
import strformat
import options
import colors
import ../rect

var debugDrawings: seq[Primitive] = @[]

template debugDraw(primitive: Primitive): void =
  debugDrawings.add(primitive)

proc debugDrawRect*(rect: Rect[float]): void =
  if not isNil rect:
    debugDraw(rectangle(bounds = rect, strokeInfo = some(StrokeInfo(width: 2.0)), colorInfo = some(ColorInfo(stroke: some("magenta".parseColor())))))

proc flushDebugDrawings*(): seq[Primitive] =
  result = debugDrawings
  debugDrawings = @[]
