import sequtils, options, sugar
import ../types
import ../element
import ../drawing_primitives
import ../../vec
import ../world_position

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

    # TODO: Chang type so one must and can only supply either data or stringData
    data*: Option[seq[PathSegment]] # TODO: Not sure we should expose this type here, but will deal with that later
    stringData*: Option[string]

  Path* = ref object of Element
    pathProps*: PathProps

method render(self: Path): Option[Primitive] =
  let props = self.pathProps
  if self.bounds.isNone():
    # TODO: Fix whatever caused the need for this check
    echo "WARN: Bounds of path was none"
    return none[Primitive]()
  let wp = self.actualWorldPosition()
  if self.pathProps.stringData.isSome:
    some(
      self.createPath(
        some(ColorInfo(fill: props.fill, stroke: props.stroke)),
        some(StrokeInfo(width: props.strokeWidth.get(1.0))),
        self.pathProps.stringData.get,
      )
    )
  elif self.pathProps.data.isSome:
    some(
      self.createPath(
        some(ColorInfo(fill: props.fill, stroke: props.stroke)),
        some(StrokeInfo(width: props.strokeWidth.get(1.0))),
        self.pathProps.data.get,
      )
    )
  else:
    echo "WARN: Path should have either stringData or data set"
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
