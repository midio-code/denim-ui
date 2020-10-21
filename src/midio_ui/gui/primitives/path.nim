import sequtils, options, sugar
import ../types
import ../element
import ../drawing_primitives
import ../../vec

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
      props.data.map(
        proc(segment: PathSegment): PathSegment =
          case segment.kind:
            of PathSegmentKind.MoveTo:
              PathSegment(kind: PathSegmentKind.MoveTo, to: segment.to + wp)
            of PathSegmentKind.LineTo:
              PathSegment(kind: PathSegmentKind.LineTo, to: segment.to + wp)
            of PathSegmentKind.QuadraticCurveTo:
              PathSegment(
                kind: PathSegmentKind.QuadraticCurveTo,
                controlPoint: segment.controlPoint + wp,
                point: segment.point + wp
              )
            of PathSegmentKind.Close:
              PathSegment(kind: PathSegmentKind.Close)

      )
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
