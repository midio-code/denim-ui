import math
import options
import types
import ../vec
import ../rect
import ../utils
import ./primitives/defaults
from colors import colWhite

proc createContainer*(self: Element, children: seq[Primitive]): Primitive =
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    kind: Container,
    children: children,
    opacity: self.props.opacity,
  )

proc moveTo*(x: float, y: float): PathSegment =
  PathSegment(kind: MoveTo, to: vec2(x,y))
proc lineTo*(x: float, y: float): PathSegment =
  PathSegment(kind: LineTo, to: vec2(x,y))
proc quadraticCurveTo*(cpx: float, cpy: float, x: float, y: float): PathSegment =
  PathSegment(kind: QuadraticCurveTo, quadraticInfo: QuadraticInfo(controlPoint: vec2(cpx, cpy), point: vec2(x, y)))
proc bezierCurveTo*(cp1x, cp1y, cp2x, cp2y, x, y: float): PathSegment =
  PathSegment(kind: BezierCurveTo, bezierInfo: BezierInfo(controlPoint1:vec2(cp1x, cp1y), controlPoint2: vec2(cp2x, cp2y), point: vec2(x, y)))
proc close*(): PathSegment =
  PathSegment(kind: Close)

proc createPath*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], segments: seq[PathSegment]): Primitive =
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    shadow: self.props.shadow,
    kind: Path,
    pathInfo: PathInfo(
      kind: PathInfoKind.Segments,
      segments: @segments
    ),
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    children: @[],
    opacity: self.props.opacity,
  )


proc createPath*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], stringData: string): Primitive =
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    shadow: self.props.shadow,
    kind: Path,
    pathInfo: PathInfo(
      kind: PathInfoKind.String,
      data: stringData
    ),
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    children: @[],
    opacity: self.props.opacity,
  )

proc createPath*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], segments: varargs[PathSegment]): Primitive =
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    shadow: self.props.shadow,
    clipToBounds: self.props.clipToBounds.get(false),
    kind: Path,
    pathInfo: PathInfo(
      kind: PathInfoKind.Segments,
      segments: @segments
    ),
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    children: @[],
    opacity: self.props.opacity,
  )

proc circle*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], center: Point, radius: float): Primitive =
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    shadow: self.props.shadow,
    clipToBounds: self.props.clipToBounds.get(false),
    kind: Circle,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    circleInfo: CircleInfo(radius: radius),
    children: @[],
    opacity: self.props.opacity,
  )

proc ellipse*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], radius: Vec2[float]): Primitive =
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    shadow: self.props.shadow,
    kind: Ellipse,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    ellipseInfo: EllipseInfo(radius: radius, endAngle: TAU),
    children: @[],
    opacity: self.props.opacity,
  )

proc image*(self: Element, uri: string): Primitive =
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    shadow: self.props.shadow,
    kind: Image,
    colorInfo: none[ColorInfo](),
    strokeInfo: none[StrokeInfo](),
    imageInfo: ImageInfo(uri: uri),
    children: @[],
    opacity: self.props.opacity,
  )

proc rectangle*(self: Element, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], radius: CornerRadius): Primitive =
  Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    shadow: self.props.shadow,
    kind: Rectangle,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    rectangleInfo: RectangleInfo(
      radius: radius,
    ),
    children: @[],
    opacity: self.props.opacity,
  )

proc rectangle*(bounds: Bounds, colorInfo: Option[ColorInfo], strokeInfo: Option[StrokeInfo], radius: CornerRadius): Primitive =
  Primitive(
    bounds: bounds,
    kind: Rectangle,
    colorInfo: colorInfo,
    strokeInfo: strokeInfo,
    rectangleInfo: RectangleInfo(
      radius: radius,
    ),
    children: @[],
  )


proc fillColor*(color: Color): ColorInfo =
  ColorInfo(fill: some(color))
