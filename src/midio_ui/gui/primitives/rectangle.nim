import strformat, options, sugar
import ../types
import ../element
import ../drawing_primitives
import ../../vec
import ../../rect

type
  RectProps* = ref object
    color*: Option[Color]
    radius*: Option[CornerRadius]
    stroke*: Option[Color]
    strokeWidth*: Option[float]

proc renderRectangle(self: Element, props: RectProps): Option[Primitive] =
  let bounds = self.bounds.get()
  let width = bounds.width()
  let height = bounds.height()
  let radius = props.radius.get((0.0, 0.0, 0.0, 0.0))

  some(
    self.createPath(
      some(ColorInfo(fill: props.color, stroke: props.stroke)),
      some(StrokeInfo(width: props.strokeWidth.get(0.0))),
      moveTo(radius[0], 0),
      lineTo(width - radius[1], 0),
      quadraticCurveTo(width, 0, width, radius[1]),
      lineTo(width, height - radius[2]),
      quadraticCurveTo(width, height, width - radius[2], height),
      lineTo(radius[3], height),
      quadraticCurveTo(0, height, 0, height - radius[3]),
      lineTo(0, radius[0]),
      quadraticCurveTo(0, 0, radius[0], 0),
      close()
    )
  )

proc createRectangle*(props: RectProps = RectProps(), elemProps: ElemProps = ElemProps(), children: seq[Element] = @[]): Element =
  newElement(
    props = elemProps,
    drawable = some(Drawable(
      name: "rectangle",
      render: (elem: Element) => renderRectangle(elem, props)
    ))
  )

proc fill*(color: Color, elemProps: ElemProps = ElemProps()): Element =
  createRectangle(props = RectProps(color: some(color)), elemProps = elemProps)

proc fill*(color: Color, radius: CornerRadius): Element =
  createRectangle(props = RectProps(color: some(color), stroke: some(color), radius: some(radius)))

proc border*(strokeColor: Color, strokeWidth: Option[float] = none[float](), radius: Option[CornerRadius] = none[CornerRadius]()): Element =
  createRectangle(props = RectProps(stroke: some(strokeColor), strokeWidth: strokeWidth, radius: radius))
