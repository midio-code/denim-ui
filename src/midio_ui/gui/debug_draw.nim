import sequtils
import tables
import drawing_primitives
import element
import strformat
import options
import ../rect

var debugDrawings: Table[string, Primitive] = initTable[string, Primitive]()

template debugDraw(primitive: Primitive): void =
  let pos = instantiationInfo()
  let instantiationHash = $pos.filename & ":" & $pos.line
  debugDrawings[instantiationHash] = primitive

proc debugDrawRect*(rect: Rect[float]): void =
  echo "Drawing debug rect: ", rect
  debugDraw(rectangle(bounds = rect, strokeInfo = some(StrokeInfo(width: 2.0)), colorInfo = some(ColorInfo(stroke: some("magenta")))))

proc flushDebugDrawings*(): seq[Primitive] =
  toSeq(debugDrawings.values())
