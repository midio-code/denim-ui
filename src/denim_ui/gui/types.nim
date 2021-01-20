import sugar
import strformat
import tables
import hashes
import options
import colors
import rx_nim

import ../guid
import ../vec
import ../transform
import ../thickness
import ../rect

export transform
export colors


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
  Point* = Vec2[float]
  Size* = Vec2[float]
  Points* = seq[Point]
  Bounds* = Rect[float]

  TextProps* = ref object
    text*: string
    fontSize*: Option[float]
    font*: Option[string]
    color*: Option[Color]
    wordWrap*: bool

  TextChanged* = string -> void

  TextInputProps* = ref object
    text*: string
    font*: Option[string]
    placeholder*: Option[string]
    fontSize*: Option[float]
    color*: Option[Color]
    placeholderColor*: Option[Color]
    onChange*: Option[TextChanged]

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
    stroke*: Option[Color]
    fill*: Option[Color]

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

  PathInfoKind* {.pure.} = enum
    Segments, String

  PathInfo* = ref object
    case kind*: PathInfoKind
    of PathInfoKind.Segments:
      segments*: seq[PathSegment]
    of PathInfoKind.String:
      data*: string


  Shadow* = ref object
    color*: Color
    alpha*: float
    size*: float
    offset*: Vec2[float]

  Primitive* = ref object
    colorInfo*: Option[ColorInfo]
    strokeInfo*: Option[StrokeInfo]
    shadow*: Option[Shadow]
    clipToBounds*: bool
    bounds*: Bounds
    transform*: seq[Transform]
    children*: seq[Primitive]
    case kind*: PrimitiveKind
    of Container: # Just a container for other primitives
      discard
    of Text:
      textInfo*: TextInfo
    of Path:
      pathInfo*: PathInfo
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
    transform*: seq[Transform]
    zIndex*: Option[int]
    # NOTE: Only for debugging
    debugName*: Option[string]
    shadow*: Option[Shadow]

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

  TextInput* = ref object of Element
    textInputProps*: TextInputProps

proc hash*(element: Element): Hash =
  element.id.hash()

proc `$`*(element: Element): string =
  &"Element({element.id})"

proc `elementProps`*(self: Element): ElementProps =
  self.props
