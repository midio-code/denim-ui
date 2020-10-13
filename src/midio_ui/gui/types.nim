import sugar
import hashes
import options
import ../guid
import ../vec
import ../thickness
import ../rect

type
  Color* = string
  Point* = Vec2[float]
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
    fontSize*: Option[float]
    color*: Option[string]
    onChange*: Option[TextChanged]

type
  PathSegmentKind* {.pure.} = enum
    MoveTo, LineTo, QuadraticCurveTo, Close
  PathSegment* = ref object
    case kind*: PathSegmentKind
    of MoveTo, LineTo:
      to*: Point
    of QuadraticCurveTo:
      controlPoint*: Point
      point*: Point
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
    pos*: Point
    alignment*: string

  PrimitiveKind* {.pure.} = enum
    Text, Path, Circle, Ellipse, Rectangle

  CircleInfo* = object
    center*: Point
    radius*: float

  EllipseInfo* = object
    center*: Point
    radius*: Vec2[float]
    rotation*: float
    startAngle*: float
    endAngle*: float

  CornerRadius* = tuple[l: float, t: float, r: float, b: float]

  RectangleInfo* = object
    bounds*: Rect[float]

  Primitive* = ref object
    colorInfo*: Option[ColorInfo]
    strokeInfo*: Option[StrokeInfo]
    clipBounds*: Option[Rect[float]]
    case kind*: PrimitiveKind
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

  Visibility* {.pure.} = enum
    Visible, Collapsed

  ElemProps* = ref object
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
    horizontalAlignment*: Option[HorizontalAlignment]
    verticalAlignment*: Option[VerticalAlignment]
    visibility*: Option[Visibility]
    clipToBounds*: Option[bool]

type
  Layout* = ref object
    name*: string # TODO: Hide this in release builds?
    measure*: (Element, Vec2[float]) -> Vec2[float]
    arrange*: (Element, Vec2[float]) -> Vec2[float]

  Drawable* = ref object
    name*: string # TODO: Hide this in release builds?
    render*: (Element) -> seq[Primitive]

  # TODO: Make children (and possible other properties private)
  # This would require moving the type declaration to the place where
  # the implementation can access its private fields.
  Element* = ref object
    id*: Guid
    children*: seq[Element]
    props*: ElemProps
    parent*: Option[Element]
    desiredSize*: Option[Vec2[float]]
    bounds*: Option[Rect[float]]
    previousArrange*: Option[Rect[float]]
    previousMeasure*: Option[Vec2[float]]
    isArrangeValid*: bool
    isMeasureValid*: bool
    measuring*: bool

    layout*: Option[Layout]
    drawable*: Option[Drawable]
    onRooted*: Option[(Element) -> void]
    onUnrooted*: Option[(Element) -> void]

    pointerInsideLastUpdate*: bool

proc hash*(element: Element): Hash =
  element.id.hash()

# TODO: Move somewhere else
proc boundsOfClosestElementWithClipToBounds*(self: Element): Option[Bounds] =
  if self.props.clipToBounds.isSome() and self.props.clipToBounds.get():
    result = self.bounds
  elif self.parent.isSome:
    result = self.parent.get().boundsOfClosestElementWithClipToBounds()
