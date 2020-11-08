import strformat, options, sugar
import ../types
import ../element
import ../drawing_primitives
import ../../vec
import ../../rect

type
  RectangleElem* = ref object of Element
    rectProps*: RectProps

  RectProps* = ref object
    color*: Option[Color]
    radius*: Option[CornerRadius]
    stroke*: Option[Color]
    strokeWidth*: Option[float]

method render(self: RectangleElem): Option[Primitive] =
  let
    props = self.rectProps
    bounds = self.bounds.get()
    width = bounds.width()
    height = bounds.height()
    radius = props.radius.get((0.0, 0.0, 0.0, 0.0))

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

proc createRectangle*(props: (RectProps, ElementProps), children: seq[Element] = @[]): RectangleElem =
  let (rectProps, elemProps) = props
  result = RectangleElem(
    rectProps: rectProps
  )
  initElement(result, elemProps, children)
