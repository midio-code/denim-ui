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
import ../type_name

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
    fontFamily*: Option[string]
    fontWeight*: Option[int]
    fontStyle*: Option[string]
    color*: Option[Color]
    wordWrap*: bool

  TextChanged* = string -> void

  TextInputProps* = ref object
    text*: string
    fontFamily*: Option[string]
    placeholder*: Option[string]
    fontSize*: Option[float]
    color*: Option[Color]
    placeholderColor*: Option[Color]
    onChange*: Option[TextChanged]
    focusWhenRooted*: Option[bool]
    wordWrap*: bool
    preventNewLineOnEnter*: bool

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
    alpha*: Option[byte]

  LineDash* = seq[int]

  LineCap* {.pure.} =  enum
    Square, Butt, Round

  LineJoin* {.pure.} = enum
    Miter, Bevel, Round

  StrokeInfo* = ref object
    width*: float
    lineDash*: Option[LineDash]
    lineCap*: Option[LineCap]
    lineJoin*: Option[LineJoin]

  TextInfo* = ref object
    text*: string
    fontSize*: float
    textBaseline*: string
    fontFamily*: string
    alignment*: string

  PrimitiveKind* {.pure.} = enum
    Container, Text, Path, Circle, Ellipse, Rectangle, Image

  ImageInfo* = ref object
    uri*: string

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
    opacity*: Option[float]
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
    of Image:
      imageInfo*: ImageInfo

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
    opacity*: Option[float]

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
    # NOTE: The hash field should be the hash of the id field, cached,
    # as an optimization to avoid having to recalculate the hash each frame.
    cachedHashOfId*: Hash
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

  Text* = ref object of Element
    textProps*: TextProps
    lines*: seq[TextLine]
    onInvalidate*: (InvalidateTextArgs) -> void

  TextLine* = tuple
    content: string
    size: Vec2[float]

  InvalidateTextArgs* = object

  TextInput* = ref object of Element
    textInputProps*: TextInputProps


  NativeElements* = ref object
    createTextInput*: ((ElementProps, TextInputProps), seq[Element]) -> TextInput
    createNativeText*: ((ElementProps, TextProps), seq[Element]) -> Text


implTypeName(Element)
implTypeName(Text)
implTypeName(TextInput)

proc hash*(element: Element): Hash =
  element.cachedHashOfId

proc `==`*(self: Element, other: Element): bool =
  if isNil(self) and isNil(other):
    return true
  if isNil(self) or isNil(other):
    return false
  self.id == other.id

proc `$`*(element: Element): string =
  let debugStr = element.props.debugName.map(x => &": {x}").get("")
  &"{element.typeName()}({element.id}{debugStr})"

proc `elementProps`*(self: Element): ElementProps =
  self.props

type
  KeyArgs* = ref object
    key*: string
    keyCode*: int
    modifiers*: seq[string]

  PointerArgs* = ref object
    # TODO: Remove sender from pointer args?
    sender*: Element
    ## The original position of the pointer in the viewport
    viewportPos*: Point
    ## The actual position of the pointer transformed to the context of the currently visited element
    actualPos*: Point # TODO: Might move this somewhere else as it is only meaningful in the context of "visiting an element" (as we do in out pointer events for example)
    pointerIndex*: PointerIndex

  WheelDeltaUnit* = enum
    Pixel, Line, Page

  WheelArgs* = object
    actualPos*: Point
    viewportPos*: Point
    deltaX*: float
    deltaY*: float
    deltaZ*: float
    unit*: WheelDeltaUnit
