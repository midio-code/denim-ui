import sequtils, options, sugar
import ../types
import ../element
import ../drawing_primitives
import ../world_position
import ../../vec
import ../../type_name
import ../../utils

export drawing_primitives.moveTo
export drawing_primitives.lineTo
export drawing_primitives.quadraticCurveTo
export drawing_primitives.bezierCurveTo
export drawing_primitives.close

type
  PathProps* = ref object
    fill*: Option[Color]
    stroke*: Option[Color]
    strokeWidth*: Option[float]
    lineDash*: Option[LineDash]
    lineCap*: Option[LineCap]
    lineJoin*: Option[LineJoin]

    # TODO: Chang type so one must and can only supply either data or stringData
    data*: Option[seq[PathSegment]] # TODO: Not sure we should expose this type here, but will deal with that later
    stringData*: Option[string]

  Path* = ref object of Element
    pathProps*: PathProps

implTypeName(Path)

method render(self: Path): Option[Primitive] =
  let props = self.pathProps
  if self.bounds.isNone():
    # TODO: Fix whatever caused the need for this check
    echo "WARN: Bounds of path was none"
    return none[Primitive]()
  if self.pathProps.stringData.isSome:
    some(
      self.createPath(
        some(ColorInfo(fill: props.fill, stroke: props.stroke)),
        some(StrokeInfo(
          width: props.strokeWidth.get(1.0),
          lineDash: props.lineDash,
          lineCap: props.lineCap,
          lineJoin: props.lineJoin
        )),
        self.pathProps.stringData.get,
      )
    )
  elif self.pathProps.data.isSome:
    some(
      self.createPath(
        some(ColorInfo(fill: props.fill, stroke: props.stroke)),
        some(StrokeInfo(
          width: props.strokeWidth.get(1.0),
          lineDash: props.lineDash,
          lineCap: props.lineCap,
          lineJoin: props.lineJoin
        )),
        self.pathProps.data.get,
      )
    )
  else:
    none[Primitive]()

# NOTE: This is set by main during initialization
# TODO: Make initialization of these native dependent functions more explicit
var hitTestPath*: (Element, PathProps, Point) -> bool

method isPointInside(self: Path, point: Point): bool =
  hitTestPath(self, self.pathProps, point)

proc initPath*(self: Path, props: PathProps): void =
  self.pathProps = props
proc createPath*(props: (ElementProps, PathProps)): Path =
  let (elemProps, pathProps) = props
  result = Path()
  initElement(result, elemProps)
  initPath(result, pathProps)
