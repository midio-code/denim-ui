import types
import options
import sugar
import element
import drawing_primitives
import ../vec
import ../rect

type
  CornerRadius* = tuple[l: float, t: float, r: float, b: float]
  RectProps* = ref object
    color*: Option[Color]
    radius*: Option[CornerRadius]
    stroke*: Option[Color]
    strokeWidth*: Option[float]

proc renderRectangle(self: Element, props: RectProps): seq[Primitive] =
  let
    worldPos = self.actualWorldPosition()
    x = worldPos.x
    y = worldPos.y
  let width = self.bounds.get().width()
  let height = self.bounds.get().height()
  let radius = props.radius.get((0.0, 0.0, 0.0, 0.0))

  @[
    self.createPath(
      some(ColorInfo(fill: props.color, stroke: props.stroke)),
      some(StrokeInfo(width: props.strokeWidth.get(1))),
      moveTo(x + radius[0], y),
      lineTo(x + width - radius[1], y),
      curveTo(x + width, y, x + width, y + radius[1]),
      lineTo(x + width, y + height - radius[2]),
      curveTo(x + width, y + height, x + width - radius[2], y + height),
      lineTo(x + radius[3], y + height),
      curveTo(x, y + height, x, y + height - radius[3]),
      lineTo(x, y + radius[0]),
      curveTo(x, y, x + radius[0], y),
      close()
    )
  ]

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
