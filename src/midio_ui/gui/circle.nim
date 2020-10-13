import types
import ../utils
import options
import sugar
import element
import drawing_primitives
import ../vec

type
  CornerRadius* = tuple[l: float, t: float, r: float, b: float]
  CircleProps* = ref object
    color*: Option[Color]
    radius*: float
    stroke*: Option[Color]
    strokeWidth*: Option[float]

proc renderCircle(self: Element, props: CircleProps): seq[Primitive] =
  let worldPos = self.actualWorldPosition()
  @[
    self.circle(
      some(ColorInfo(fill: props.color, stroke: props.stroke)),
      some(StrokeInfo(width: props.strokeWidth.get(1))),
      worldPos,
      props.radius
    )
  ]

proc measureCircle*(self: Element, availableSize: Vec2[float], props: CircleProps): Vec2[float] =
  let diameter = props.radius * 2.0
  vec2(max(diameter, self.props.width.get(0.0)), max(diameter, self.props.height.get(0.0)))

proc createCircle*(props: CircleProps = CircleProps(), elemProps: ElemProps = ElemProps(), children: seq[Element] = @[]): Element =
  result = Element(props: elemProps)
  result.layout = some(Layout(
    measure: (self: Element, availableSize: Vec2[float]) => measureCircle(self, availableSize, props)
  ))
  result.drawable = some(Drawable(
    name: "circle",
    render: (elem: Element) => renderCircle(elem, props)
  ))

proc createCircle*(color: Color, pos: Vec2[float], radius: float): Element =
  createCircle(CircleProps(color: some(color), radius: radius), ElemProps(x: pos.x, y: pos.y))

proc createCircle*(color: Color, radius: float): Element =
  createCircle(CircleProps(color: some(color), radius: radius), ElemProps(horizontalAlignment: HorizontalAlignment.Center))
