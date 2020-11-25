import math
import options
import types
import ../vec
import ../rect
import ../utils
import ./primitives/defaults

proc createTextPrimitive*(
  self: Element,
  text: string,
  color: Color = colWhite,
  fontSize: float = 12.0,
  font: string = defaults.font,
  textBaseline: string = "top",
  alignment: string = "left"
): Primitive =
  let textInfo = TextInfo(
    text: text,
    fontSize: fontSize,
    textBaseline: textBaseline,
    font: font,
    alignment: alignment
  )
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    kind: Text,
    textInfo: textInfo,
    colorInfo: ColorInfo(fill: color),
    children: @[],
  )

proc moveTo*(x: float, y: float): PathSegment =
  PathSegment(kind: MoveTo, to: vec2(x,y))
proc lineTo*(x: float, y: float): PathSegment =
  PathSegment(kind: LineTo, to: vec2(x,y))
proc quadraticCurveTo*(cpx: float, cpy: float, x: float, y: float): PathSegment =
  PathSegment(kind: QuadraticCurveTo, quadraticInfo: (vec2(cpx, cpy), vec2(x, y)))
proc bezierCurveTo*(cp1x, cp1y, cp2x, cp2y, x, y: float): PathSegment =
  PathSegment(kind: BezierCurveTo, bezierInfo: (vec2(cp1x, cp1y), vec2(cp2x, cp2y), vec2(x, y)))
proc close*(): PathSegment =
  PathSegment(kind: Close)

proc createPath*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], segments: seq[PathSegment]): Primitive =
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    kind: Path,
    segments: @segments,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    children: @[],
  )

proc createPath*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], segments: varargs[PathSegment]): Primitive =
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    kind: Path,
    segments: @segments,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    children: @[],
  )

proc circle*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], center: Point, radius: float): Primitive =
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    kind: Circle,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    circleInfo: CircleInfo(radius: radius),
    children: @[],
  )

proc ellipse*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], radius: Vec2[float]): Primitive =
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    kind: Ellipse,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    ellipseInfo: EllipseInfo(radius: radius, endAngle: TAU),
    children: @[],
  )

proc rectangle*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo]): Primitive =
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    kind: Rectangle,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    rectangleInfo: RectangleInfo(bounds: self.bounds.get()),
    children: @[],
  )

proc rectangle*(bounds: Bounds, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo]): Primitive =
  echo "Debug rect: ", bounds.size
  Primitive(
    bounds: bounds,
    kind: Rectangle,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    rectangleInfo: RectangleInfo(bounds: bounds),
    children: @[],
  )

proc fillColor*(color: Color): ColorInfo =
  ColorInfo(fill: some(color))
