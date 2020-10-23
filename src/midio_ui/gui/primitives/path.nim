import sequtils, options, sugar
import ../types
import ../element
import ../drawing_primitives
import ../../vec

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
    data*: seq[PathSegment] # TODO: Not sure we should expose this type here, but will deal with that later

# proc internalMeasure(self: Element, props: PathProps): Vec2[float] =
#   var smallest = zero()
#   var largest = zero()
#   for p in props.data:
#     var point: Point = zero()
#     case p.kind:
#       of PathSegmentKind.MoveTo, PathSegmentKind.LineTo:
#         point = p.to
#       of PathSegmentKind.QuadraticCurveTo:
#         point = p.quadraticInfo.point
#       of PathSegmentKind.BezierCurveTo:
#         point = p.bezierInfo.point
#       else: discard
#     smallest = min(point, smallest)
#     largest = max(point, largest)
#   result = largest - smallest
#   echo "Result is: ", result


proc renderPath(self: Element, props: PathProps): Option[Primitive] =
  if self.bounds.isNone():
    # TODO: Fix whatever caused the need for this check
    echo "WARN: Bounds of path was none"
    return none[Primitive]()
  let wp = self.actualWorldPosition()
  some(
    self.createPath(
      some(ColorInfo(fill: props.fill, stroke: props.stroke)),
      some(StrokeInfo(width: props.strokeWidth.get(1.0))),
      props.data,
    )
  )

# NOTE: This is set by main during initialization
# TODO: Make initialization of these native dependent functions more explicit
var hitTestPath*: (Element, PathProps, Point) -> bool

proc createPath*(props: PathProps = PathProps(), elemProps: ElemProps = ElemProps(), children: seq[Element] = @[]): Element =
  newElement(
    props = elemProps,
    # layout = some(
    #   Layout(
    #     name: "path(layout)",
    #     measure: (self: Element, avSize: Vec2[float]) => internalMeasure(self, props),
    #   )
    # ),
    hitTest = some(
      proc(e: Element, p: Point): bool =
        hitTestPath(e, props, p)
    ),
    drawable = some(Drawable(
      name: "path",
      render: (elem: Element) => renderPath(elem, props)
    ))
  )
