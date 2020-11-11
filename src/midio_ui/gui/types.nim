import sugar, strformat
import tables
import hashes
import options
import ../guid
import ../vec
import ../transform
import ../thickness
import ../rect

export transform

type
  PointerIndex* = enum
    Primary = 0, Middle = 1, Secondary = 2

proc isPrimary*(pi: PointerIndex): bool =
  pi == PointerIndex.Primary
proc isSecondary*(pi: PointerIndex): bool =
  pi == PointerIndex.Secondary
proc isMiddle*(pi: PointerIndex): bool =
  pi == PointerIndex.Middle

type
  Color* = string
  Point* = Vec2[float]
  Size* = Vec2[float]
  Points* = seq[Point]
  Bounds* = Rect[float]

  TextProps* = ref object
    text*: string
    fontSize*: Option[float]
    font*: Option[string]
    color*: Option[string]

  TextChanged* = (string) -> void

  TextInputProps* = ref object
    text*: string
    font*: Option[string]
    placeholder*: Option[string]
    fontSize*: Option[float]
    color*: Option[string]
    placeholderColor*: Option[string]
    onChange*: Option[TextChanged]


type

  PathSegmentKind* {.pure.} = enum
    MoveTo, LineTo, QuadraticCurveTo, BezierCurveTo, Close
  PathSegment* = ref object
    case kind*: PathSegmentKind
    of MoveTo, LineTo:
      to*: Point
    of QuadraticCurveTo:
      quadraticInfo*: tuple[
        controlPoint: Point,
        point: Point
      ]
    of BezierCurveTo:
      bezierInfo*: tuple[
        controlPoint1: Point,
        controlPoint2: Point,
        point: Point
      ]
    of Close:
      discard

  ColorInfo* = ref object
    stroke*: Option[string]
    fill*: Option[string]

  StrokeInfo* = ref object
    width*: float

  TextInfo* = ref object
    text*: string
    fontSize*: float
    textBaseline*: string
    font*: string
    alignment*: string

  PrimitiveKind* {.pure.} = enum
    Container, Text, Path, Circle, Ellipse, Rectangle

  CircleInfo* = ref object
    radius*: float

  EllipseInfo* = ref object
    radius*: Vec2[float]
    rotation*: float
    startAngle*: float
    endAngle*: float

  CornerRadius* = tuple[l: float, t: float, r: float, b: float]

  RectangleInfo* = ref object
    bounds*: Rect[float]

  Primitive* = ref object
    colorInfo*: Option[ColorInfo]
    strokeInfo*: Option[StrokeInfo]
    clipToBounds*: bool
    bounds*: Bounds
    transform*: Option[Transform]
    children*: seq[Primitive]
    case kind*: PrimitiveKind
    of Container: # Just a container for other primitives
      discard
    of Text:
      textInfo*: TextInfo
    of Path:
      segments*: seq[PathSegment]
    of Circle:
      circleInfo*: CircleInfo
    of Ellipse:
      ellipseInfo*: EllipseInfo
    of Rectangle:
      rectangleInfo*: RectangleInfo

type
  HorizontalAlignment* {.pure.} = enum
    Stretch, Center, Left, Right

  VerticalAlignment* {.pure.} = enum
    Stretch, Center, Top, Bottom

  Alignment* {.pure.} = enum
    Stretch, Left, TopLeft, Top, TopRight, Right,
    BottomRight, Bottom, BottomLeft, Center,
    CenterLeft, CenterRight, TopCenter, BottomCenter,
    HorizontalCenter, VerticalCenter

proc horizontalPart*(alignment: Alignment): HorizontalAlignment =
  case alignment:
    of Alignment.Left, TopLeft, BottomLeft, CenterLeft: HorizontalAlignment.Left
    of Alignment.Center, TopCenter, BottomCenter, HorizontalCenter: HorizontalAlignment.Center
    of Alignment.Right, TopRight, BottomRight, CenterRight: HorizontalAlignment.Right
    of Alignment.Top, Alignment.Bottom, VerticalCenter, Alignment.Stretch: HorizontalAlignment.Stretch

proc verticalPart*(alignment: Alignment): VerticalAlignment =
  case alignment:
    of Alignment.Top, TopLeft, TopRight, TopCenter: VerticalAlignment.Top
    of Alignment.Bottom, BottomLeft, BottomRight, BottomCenter: VerticalAlignment.Bottom
    of VerticalCenter, Alignment.Center, CenterLeft, CenterRight: VerticalAlignment.Center
    of Alignment.Left, Alignment.Right, HorizontalCenter, Alignment.Stretch: VerticalAlignment.Stretch

type
  Visibility* {.pure.} = enum
    Visible, Collapsed, Hidden

  ElementProps* = ref object
    width*: Option[float]
    height*: Option[float]
    maxWidth*: Option[float]
    minWidth*: Option[float]
    maxHeight*: Option[float]
    minHeight*: Option[float]
    x*: Option[float]
    y*: Option[float]
    xOffset*: Option[float]
    yOffset*: Option[float]
    margin*: Option[Thickness[float]]
    alignment*: Option[Alignment]
    visibility*: Option[Visibility]
    clipToBounds*: Option[bool]
    # TODO: Implement all transforms for all rendering backends
    transform*: Option[Transform]
    # NOTE: Only for debugging
    debugName*: Option[string]

proc translation*(trans: Vec2[float]): Transform =
  Transform(scale: vec2(1.0), rotation: 0.0, translation: trans)

proc scale*(scale: Vec2[float]): Transform =
  Transform(scale: scale, rotation: 0.0, translation: vec2(0.0))

proc rotation*(rot: float): Transform =
  Transform(scale: vec2(1.0), rotation: rot, translation: vec2(0.0))

type
  Layout* = ref object
    name*: string # TODO: Hide this in release builds?
    measure*: (Element, Vec2[float]) -> Vec2[float]
    arrange*: (Element, Vec2[float]) -> Vec2[float]

  Drawable* = ref object
    name*: string # TODO: Hide this in release builds?
    render*: (Element) -> Option[Primitive]

  # TODO: Make children (and possible other properties private)
  # This would require moving the type declaration to the place where
  # the implementation can access its private fields.
  Element* = ref object of RootObj
    id*: Guid
    children*: seq[Element]
    props*: ElementProps
    parent*: Option[Element]
    desiredSize*: Option[Vec2[float]]
    bounds*: Option[Rect[float]]
    previousArrange*: Option[Rect[float]]
    previousMeasure*: Option[Vec2[float]]
    isArrangeValid*: bool
    isMeasureValid*: bool
    measuring*: bool

    isRooted*: bool

    pointerInsideLastUpdate*: bool

proc hash*(element: Element): Hash =
  element.id.hash()

proc `elementProps`*(self: Element): ElementProps =
  self.props

# TODO: This is probably not a robust way to cache this, and is just a
# proof of concept for caching values that depends on layout calculations
var worldPositions = initTable[Element, Vec2[float]]()
# TODO: Find a better place for this
#
proc actualWorldPosition*(self: Element): Vec2[float] =
  if worldPositions.hasKey(self):
    worldPositions[self]
  elif self.bounds.isSome():
    var actualPos = self.bounds.get().pos
    if self.parent.isSome():
      actualPos = self.parent.get().actualWorldPosition().add(actualPos)
    worldPositions[self] = actualPos
    actualPos
  else:
    vec2(0.0)

proc invalidateWorldPositionsCache*(): void =
  worldPositions.clear()

type
  TextInput* = ref object of Element
    textInputProps*: TextInputProps
