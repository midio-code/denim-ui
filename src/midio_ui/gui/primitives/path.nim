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

proc createPath*(props: PathProps = PathProps(), elemProps: ElemProps = ElemProps(), children: seq[Element] = @[]): Element =
  newElement(
    props = elemProps,
    drawable = some(Drawable(
      name: "path",
      render: (elem: Element) => renderPath(elem, props)
    ))
  )
