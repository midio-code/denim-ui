import options, sugar
import ../types
import ../element
import ../drawing_primitives
import ../../vec
import ../../utils

type
  CircleProps* = ref object
    color*: Option[Color]
    radius*: float
    stroke*: Option[Color]
    strokeWidth*: Option[float]

  Circle* = ref object of Element
    circleProps*: CircleProps

method render(self: Circle): Option[Primitive] =
  let props = self.circleProps
  let worldPos = self.actualWorldPosition()
  some(
    self.circle(
      some(ColorInfo(fill: props.color, stroke: props.stroke)),
      some(StrokeInfo(width: props.strokeWidth.get(1))),
      worldPos,
      props.radius
    )
  )

method measureOverride*(self: Circle, availableSize: Vec2[float]): Vec2[float] =
  let props = self.circleProps
  let diameter = props.radius * 2.0
  vec2(max(diameter, self.props.width.get(0.0)), max(diameter, self.props.height.get(0.0)))

proc createCircle*(props: CircleProps = CircleProps(), elemProps: ElemProps = ElemProps(), children: seq[Element] = @[]): Circle =
  result = Circle(
    circleProps: props
  )
  initElement(result, elemProps, children)
