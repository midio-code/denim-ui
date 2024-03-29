import sugar
import strformat
import strutils
import tables
import hashes
import options
import color
import rx_nim

import ../guid
import ../vec
import ../circle
import ../transform
import ../thickness
import ../rect
import ../type_name

export color
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
    lineHeight*: Option[float]


  TextChangedInfo* = ref object
    selectionStart*: int
    selectionEnd*: int
  TextChanged* = (string, TextChangedInfo) -> void

  TextInputProps* = ref object
    text*: string
    fontFamily*: Option[string]
    fontWeight*: Option[int]
    fontStyle*: Option[string]
    placeholder*: Option[string]
    fontSize*: Option[float]
    color*: Option[Color]
    placeholderColor*: Option[Color]
    onChange*: Option[TextChanged]
    focusWhenRooted*: Option[bool]
    preventNewLineOnEnter*: bool
    wordWrap*: bool
    ## The height of each line in pixels
    lineHeight*: Option[float]

  BezierInfo* = ref object
    controlPoint1*: Point
    controlPoint2*: Point
    point*: Point

  QuadraticInfo* = ref object
    controlPoint*: Point
    point*: Point

  PathSegmentKind* {.pure.} = enum
    MoveTo, LineTo, QuadraticCurveTo, BezierCurveTo, Close
  PathSegment* = ref object
    case kind*: PathSegmentKind
    of MoveTo, LineTo:
      to*: Point
    of QuadraticCurveTo:
      quadraticInfo*: QuadraticInfo
    of BezierCurveTo:
      bezierInfo*: BezierInfo
    of Close:
      discard

  GradientStop* = tuple[color: Color, position: float]
  LinearGradient* = ref object
    startPoint*: Point
    endPoint*: Point
  RadialGradient* = ref object
    startCircle*: Circle
    endCircle*: Circle
  GradientKind* {.pure.} = enum
    Linear, Radial
  Gradient* = ref object
    stops*: seq[GradientStop]
    case kind*: GradientKind
    of GradientKind.Linear:
      linearInfo*: LinearGradient
    of GradientKind.Radial:
      radialInfo*: RadialGradient

  ColorStyleKind* {.pure.} = enum
    Solid, Gradient
  ColorStyle* = ref object
    case kind*: ColorStyleKind
    of ColorStyleKind.Solid:
      color*: Color
    of ColorStyleKind.Gradient:
      gradient*: Gradient

  ColorInfo* = ref object
    stroke*: Option[ColorStyle]
    fill*: Option[ColorStyle]

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
    hash: Hash
    text*: cstring
    fontSize*: float
    textBaseline*: cstring
    fontFamily*: cstring
    fontWeight*: int
    fontStyle*: cstring
    alignment*: cstring
    textSize*: Size

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

  CornerRadius* = ref object
    topLeft*: float
    topRight*: float
    bottomRight*: float
    bottomLeft*: float

  RectangleInfo* = ref object
    radius*: CornerRadius

  PathInfoKind* {.pure.} = enum
    Segments, String

  PathInfo* = ref object
    case kind*: PathInfoKind
    of PathInfoKind.Segments:
      segments*: seq[PathSegment]
    of PathInfoKind.String:
      data*: cstring


  Shadow* = ref object
    color*: Color
    size*: float
    offset*: Vec2[float]

  Primitive* = ref object
    id*: Hash
    cache*: bool
    colorInfo*: Option[ColorInfo]
    strokeInfo*: Option[StrokeInfo]
    shadow*: Option[Shadow]
    clipToBounds*: bool
    bounds*: Bounds
    opacity*: Option[float]
    transform*: seq[Transform]
    children*: seq[Primitive]
    case kind*: PrimitiveKind
    of PrimitiveKind.Container: # Just a container for other primitives
      discard
    of PrimitiveKind.Text:
      textInfo*: TextInfo
    of PrimitiveKind.Path:
      pathInfo*: PathInfo
    of PrimitiveKind.Circle:
      circleInfo*: CircleInfo
    of PrimitiveKind.Ellipse:
      ellipseInfo*: EllipseInfo
    of PrimitiveKind.Rectangle:
      rectangleInfo*: RectangleInfo
    of PrimitiveKind.Image:
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
    cacheVisual*: Option[bool]
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
    isVisualValid*: bool
    measuring*: bool

    isRooted*: bool

    pointerInsideLastUpdate*: bool

  Text* = ref object of Element
    textProps*: TextProps
    lines*: seq[TextLine]
    onInvalidate*: (InvalidateTextArgs) -> void

  TextLine* = ref object
    content*: string
    textSize*: Size


  InvalidateTextArgs* = object

  TextInput* = ref object of Element
    textInputProps*: TextInputProps


  NativeElements* = ref object
    createTextInput*: ((ElementProps, TextInputProps), seq[Element]) -> TextInput
    createNativeText*: ((ElementProps, TextProps), seq[Element]) -> Text

proc radius*(tl,tr,br,bl: float): CornerRadius =
  CornerRadius(
    topLeft: tl,
    topRight: tr,
    bottomRight: br,
    bottomLeft: bl
  )

converter cornerRadiusFromTuple*(self: (float, float, float, float)): CornerRadius =
  radius(self[0], self[1], self[2], self[3])

converter cornerRadiusFromOptionTuple*(self: (float, float, float, float)): Option[CornerRadius] =
  some(cornerRadiusFromTuple(self))

implTypeName(Element)
implTypeName(Text)
implTypeName(TextInput)

proc hash*(element: Element): Hash =
  element.cachedHashOfId

proc hash*(primitive: Primitive): Hash =
  primitive.id

proc hash*(self: TextInfo): Hash =
  self.hash

proc newTextInfo*(
    text: cstring,
    fontSize: cfloat,
    textBaseline: cstring,
    fontFamily: cstring,
    fontWeight: int,
    fontStyle: cstring = "top",
    alignment: cstring = "left",
    textSize: Size,
): TextInfo =
  var h: Hash = 0
  h = h !& text.hash()
  # NOTE: A bug in the JS target causes hashes of floats to fail
  # TODO: Remove stringifying when https://github.com/nim-lang/Nim/issues/16542 fix is released
  h = h !& ($fontSize).hash()
  h = h !& fontFamily.hash()
  h = h !& fontWeight.hash()
  h = h !& fontStyle.hash()
  TextInfo(
    hash: !$h,
    text: text,
    fontSize: fontSize,
    textBaseline: textBaseline,
    fontFamily: fontFamily,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    alignment: alignment,
    textSize: textSize,
  )

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


proc `$`*(self: ColorStyle): string =
  case self.kind:
    of ColorStyleKind.Solid:
       $self.color
    else:
      raise newException(Exception, "$ not implemented for color kind {self.kind}")

proc toHexCStr*(self: ColorStyle): cstring =
  case self.kind:
    of ColorStyleKind.Solid:
       self.color.toHexCStr()
    else:
      raise newException(Exception, "$ not implemented for color kind {self.kind}")


proc newSolidColor*(color: Color): ColorStyle =
  ColorStyle(
    kind: ColorStyleKind.Solid,
    color: color
  )

proc newLinearGradient*(startPoint, endPoint: Point, stops: varargs[GradientStop]): ColorStyle =
  ColorStyle(
    kind: ColorStyleKind.Gradient,
    gradient: Gradient(
      kind: GradientKind.Linear,
      linearInfo: LinearGradient(
        startPoint: startPoint,
        endPoint: endPoint,
      ),
      stops: @stops
    )
  )

proc newRadialGradient*(startCircle, endCircle: Circle, stops: varargs[GradientStop]): ColorStyle =
  ColorStyle(
    kind: ColorStyleKind.Gradient,
    gradient: Gradient(
      kind: GradientKind.Radial,
      radialInfo: RadialGradient(
        startCircle: startCircle,
        endCircle: endCircle,
      ),
      stops: @stops
    )
  )

converter toSolidColor*(color: Color): ColorStyle =
  newSolidColor(color)

converter toSolidColorOpt*(color: Color): Option[ColorStyle] =
  some(newSolidColor(color))

type
  Dispose* = () -> void
