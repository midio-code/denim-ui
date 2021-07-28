import strformat, options, sugar
import ../types
import ../element
import ../drawing_primitives
import ../../vec
import ../../rect
import ../../type_name

type
  RectangleElem* = ref object of Element
    rectangleProps*: RectangleProps

  RectangleProps* = ref object
    color*: Option[ColorStyle]
    radius*: Option[CornerRadius]
    stroke*: Option[ColorStyle]
    strokeWidth*: Option[float]
    lineDash*: Option[LineDash]
    lineCap*: Option[LineCap]
    lineJoin*: Option[LineJoin]

implTypeName(RectangleElem)

method render(self: RectangleElem): Option[Primitive] =
  let
    props = self.rectangleProps
    bounds = self.bounds.get()
    width = bounds.width()
    height = bounds.height()
    radius = props.radius.get((0.0, 0.0, 0.0, 0.0))

  some(
    self.rectangle(
      some(ColorInfo(
        fill: props.color,
        stroke: props.stroke,
      )),
      some(StrokeInfo(
        width: props.strokeWidth.get(1.0),
        lineDash: props.lineDash,
        lineCap: props.lineCap,
        lineJoin: props.lineJoin
      )),
      radius
    )
  )

proc createRectangle*(props: (ElementProps, RectangleProps)): RectangleElem =
  let (elemProps, rectProps) = props
  result = RectangleElem(
    rectangleProps: rectProps
  )
  initElement(result, elemProps)
