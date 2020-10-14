import math
import options
import types
import ../vec
import ../rect
import ../utils

proc createTextPrimitive*(
  self: Element,
  text: string,
  pos: Point = vec2(0.0,0.0),
  color: string = "white",
  fontSize: float = 12.0,
  font: string = "system-ui",
  textBaseline: string = "top",
  alignment: string = "left"
): Primitive =
  let textInfo = TextInfo(text: text, fontSize: fontSize, textBaseline: textBaseline, font: font, pos: pos, alignment: alignment)
  Primitive(
    transform: self.props.transform,
    worldPos: self.actualWorldPosition(),
    size: self.bounds.get().size,
    clipBounds: self.boundsOfClosestElementWithClipToBounds(),
    kind: Text,
    textInfo: textInfo,
    colorInfo: ColorInfo(fill: color)
  )

proc moveTo*(x: float, y: float): PathSegment =
  PathSegment(kind: MoveTo, to: vec2(x,y))
proc lineTo*(x: float, y: float): PathSegment =
  PathSegment(kind: LineTo, to: vec2(x,y))
proc curveTo*(cpx: float, cpy: float, x: float, y: float): PathSegment =
  PathSegment(kind: QuadraticCurveTo, controlPoint: vec2(cpx, cpy), point: vec2(x, y))
proc close*(): PathSegment =
  PathSegment(kind: Close)

proc createPath*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], segments: seq[PathSegment]): Primitive =
  Primitive(
    transform: self.props.transform,
    worldPos: self.actualWorldPosition,
    size: self.bounds.get().size,
    clipBounds: self.boundsOfClosestElementWithClipToBounds(),
    kind: Path,
    segments: @segments,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
  )

proc createPath*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], segments: varargs[PathSegment]): Primitive =
  Primitive(
    transform: self.props.transform,
    worldPos: self.actualWorldPosition,
    size: self.bounds.get().size,
    clipBounds: self.boundsOfClosestElementWithClipToBounds(),
    kind: Path,
    segments: @segments,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
  )

proc circle*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], center: Point, radius: float): Primitive =
  Primitive(
    transform: self.props.transform,
    worldPos: self.actualWorldPosition,
    size: self.bounds.get().size,
    clipBounds: self.boundsOfClosestElementWithClipToBounds(),
    kind: Circle,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    circleInfo: CircleInfo(center: center, radius: radius),
  )

proc ellipse*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], center: Point, radius: Vec2[float]): Primitive =
  Primitive(
    transform: self.props.transform,
    worldPos: self.actualWorldPosition,
    size: self.bounds.get().size,
    clipBounds: self.boundsOfClosestElementWithClipToBounds(),
    kind: Ellipse,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    ellipseInfo: EllipseInfo(center: center, radius: radius, endAngle: TAU),
  )

proc rectangle*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo]): Primitive =
  Primitive(
    transform: self.props.transform,
    worldPos: self.actualWorldPosition,
    size: self.bounds.get().size,
    clipBounds: self.boundsOfClosestElementWithClipToBounds(),
    kind: Rectangle,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    rectangleInfo: RectangleInfo(bounds: self.bounds.get()),
  )

proc rectangle*(bounds: Bounds, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo]): Primitive =
  Primitive(
    clipBounds: none[Bounds](),
    kind: Rectangle,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    rectangleInfo: RectangleInfo(bounds: bounds),
  )

proc fillColor*(color: Color): ColorInfo =
  ColorInfo(fill: some(color))
