import sugar, tables, strformat, options, macros, strutils, sets, sequtils
import ../vec
import ../rect
import ../thickness
import ../utils
import ../guid
import drawing_primitives
import element_bounds_changed_event
import ../events
import types
import tag

export types

# NOTE: Forward declarations
proc isRoot*(self: Element): bool
proc measure*(self: Element, availableSize: Vec2[float]): void
proc arrange*(self: Element, rect: Rect): void

type
  LayoutManager = ref object
    toMeasure: HashSet[Element]
    toArrange: HashSet[Element]

proc initLayoutManager*(): LayoutManager =
  LayoutManager(toMeasure: initHashSet[Element](), toArrange: initHashSet[Element]())

proc log*(self: Element, message: string): void =
  echo &"{self.id}: {message}"

let instance = initLayoutManager()

proc measure*(self: LayoutManager, elem: Element, availableSize: Vec2[float]): void =
  if not elem.isRooted:
    return

  let parent = elem.parent
  if parent.isSome():
    self.measure(parent.get(), availableSize)

  if not elem.isMeasureValid:
    if elem.isRoot:
      elem.measure(availableSize)
    elif elem.previousMeasure.isSome():
      elem.measure(elem.previousMeasure.get())

proc arrange*(self: LayoutManager, elem: Element, rect: Bounds): void =
  if not elem.isRooted:
    echo "WARN: Tried to arrange an unrooted element: ", elem.id
    return

  let parent = elem.parent
  if parent.isSome():
    self.arrange(parent.get(), rect)

  if not elem.isArrangeValid:
    if elem.isRoot():
      elem.arrange(rect)
    elif elem.previousArrange.isSome():
      elem.arrange(elem.previousArrange.get())
    else:
      echo "Tried to arrange element without a desired size"

      # TODO(important): This is wrong, we cannot use the entire rect as available space for any other element than the root!
proc performOutstandingMeasure(self: LayoutManager, availableSize: Vec2[float]): void =
  while self.toMeasure.len() > 0:
    let elem = self.toMeasure.pop()
    self.measure(elem, availableSize)

# TODO(important): This is wrong, we cannot use the entire rect as available space for any other element than the root!
proc performOutstandingArrange(self: LayoutManager, rect: Bounds): void =
  while self.toArrange.len() > 0:
    let elem = self.toArrange.pop()
    self.arrange(elem, rect)


# NOTE: Defines: onBeforeLayout, emitLayoutPerformed
createEvent(beforeLayout, Bounds)

# NOTE: Defines: onLayoutPerformed, emitLayoutPerformed
createEvent(layoutPerformed, Bounds)

# TODO(important): This is wrong, we cannot use the entire rect as available space for any other element than the root!
proc performOutstandingLayoutsAndMeasures*(rect: Bounds): void =
  emitBeforeLayout(rect)
  instance.performOutstandingMeasure(rect.size)
  instance.performOutstandingArrange(rect)
  emitLayoutPerformed(rect)

proc invalidateArrange(self: Element): void =
  self.isArrangeValid = false
  if self.isRooted:
    instance.toArrange.incl(self)

proc invalidateMeasure(self: Element): void =
  self.isMeasureValid = false
  if self.isRooted:
    instance.toMeasure.incl(self)
  self.invalidateArrange()


# TODO: We are currently performing layout on the entire tree when any element invalidates.
# this hould be optimized in the future, so that we only perform layout on the elements for which it
# is strictly necessary
proc invalidateLayout*(self: Element): void =
  self.invalidateMeasure()

# ======== ELEMENT IMPLEMENTATION ======================
# NOTE: Atm we have the LayoutManager implementation in the same file so that we avoid
# the need for circular dependencies. Will figure this out later

proc size*(props: ElementProps): Option[Vec2[float]] =
  if props.width.isSome() and props.height.isSome():
    some(vec2(props.width.get, props.height.get))
  else:
    none[Vec2[float]]()

proc `size=`*(props: ElementProps, value: Vec2[float]): void =
  props.width = some(value.x)
  props.height = some(value.y)


proc pos*(props: ElementProps): Option[Vec2[float]] =
  if props.width.isSome() and props.height.isSome():
    some(vec2(props.x.get, props.y.get))
  else:
    none[Vec2[float]]()

proc `pos=`*(props: ElementProps, value: Vec2[float]): void =
  props.x = some(value.x)
  props.y = some(value.y)

proc isRoot*(self: Element): bool =
  self.hasTag("root")

proc getRoot*(self: Element): Element =
  if self.isRoot:
    return self
  result = self
  while result.parent.isSome():
    result = result.parent.get()

method onRooted*(self: Element): void {.base.} =
  discard

proc dispatchOnRooted*(self: Element): void =
  self.isRooted = true
  self.onRooted()
  for child in self.children:
    child.dispatchOnRooted()


method onUnrooted*(self: Element): void {.base.} =
  discard

proc dispatchOnUnrooted*(self: Element): void =
  self.isRooted = false
  self.onUnrooted()
  for child in self.children:
    child.dispatchOnUnrooted()

# TODO: Remove the need for this forward declaration
proc addChild*(self: Element, child: Element): void =
  self.children.add(child)
  child.parent = some(self)
  self.invalidateLayout()
  if self.isRooted or self.isRoot:
    child.dispatchOnRooted()

proc detachFromParent(self: Element): void =
  self.parent = none[Element]()
  self.dispatchOnUnrooted()

proc removeChild*(self: Element, child: Element): void =
  let index = self.children.find(child)
  if index >= 0:
    self.children.delete(index)
    self.invalidateLayout()
    child.detachFromParent()

# TODO: Hide the children field or make this easier to discover
proc setChildren*(self: Element, value: seq[Element]): void =
  for child in self.children:
    child.detachFromParent()
  self.children = @[]
  for child in value:
    self.addChild(child)

proc initElement*(
  self: Element,
  props: ElementProps = ElementProps(),
  children: seq[Element] = @[]
): void =
  self.id = genGuid()
  self.props = props
  self.children = children
  for child in children:
    child.parent = self

type
  MinMax = object
    minWidth: float
    maxWidth: float
    minHeight: float
    maxHeight: float

proc minMax(e: Element): MinMax =
  var maxHeight = e.props.maxHeight.get(INF)
  var minHeight = e.props.minHeight.get(0.0)

  var height = e.props.height.get(INF)
  maxHeight = max(min(height, maxHeight), minHeight)

  height = e.props.height.get(0.0)
  minHeight = max(min(maxHeight, height), minHeight)

  var maxWidth = e.props.maxWidth.get(INF)
  var minWidth = e.props.minWidth.get(0.0)

  var width = e.props.width.get(INF)
  maxWidth = max(min(width, maxWidth), minWidth)

  width = e.props.width.get(0.0)
  minWidth = max(min(maxWidth, width), minWidth)

  MinMax(
    minWidth: minWidth,
    maxWidth: maxWidth,
    minHeight: minHeight,
    maxHeight: maxHeight
  )

proc applyLayoutConstraints*(element: Element, constraints: Vec2[float]): Vec2[float] =
  let mm = element.minMax()
  vec2(
    clamp(constraints.x, mm.minWidth, mm.maxWidth),
    clamp(constraints.y, mm.minHeight, mm.maxHeight)
  )

proc margin*(p: Element): Thickness[float] =
  p.props.margin.get(thickness(0.0))

# Forward declaration
method arrangeOverride*(self: Element, finalSize: Vec2[float]): Vec2[float] {.base.} =
  var largestChild = zero()
  for child in self.children:
    if child.desiredSize.isSome():
      largestChild = largestChild.max(child.desiredSize.get())

  let arrangeRect = rect(zero(), finalSize.max(largestChild))
  for child in self.children:
    child.arrange(arrangeRect)

  arrangeRect.size

proc arrangeCore(self: Element, finalRect: Bounds): void =

  let margin = self.margin()
  var originX = finalRect.x() + margin.left()
  var originY = finalRect.y() + margin.top()
  var availableSizeMinusMargins = vec2(
    max(0.0, finalRect.width() - margin.left() - margin.right()),
    max(0.0, finalRect.height() - margin.top() - margin.bottom())
  )
  let alignment = self.props.alignment.get(Alignment.Stretch)
  let horizontalAlignment = alignment.horizontalPart
  let verticalAlignment = alignment.verticalPart
  var size = availableSizeMinusMargins

  if horizontalAlignment != HorizontalAlignment.Stretch:
    size = size.withX(min(size.x, self.desiredSize.get().x - margin.left() - margin.right()))

  if verticalAlignment != VerticalAlignment.Stretch:
    size = size.withY(min(size.y, self.desiredSize.get().y - margin.top() - margin.bottom()))

  size = self.applyLayoutConstraints(size)
  size = self.arrangeOverride(size).constrain(size)

  case horizontalAlignment:
  of HorizontalAlignment.Center, HorizontalAlignment.Stretch:
    originX += (availableSizeMinusMargins.x - size.x) / 2.0;
  of HorizontalAlignment.Right:
    originX += availableSizeMinusMargins.x - size.x;
  else: discard

  case verticalAlignment:
  of VerticalAlignment.Center, VerticalAlignment.Stretch:
    originY += (availableSizeMinusMargins.y - size.y) / 2.0;
  of VerticalAlignment.Bottom:
    originY += availableSizeMinusMargins.y - size.y;
  else: discard

  # if self.props.visibility == Visibility.Collapsed:
  #   self.bounds = rect(
  #     vec2(self.props.x.get(originX) + self.props.xOffset.get(0), self.props.y.get(originY) + self.props.yOffset.get(0)),
  #     vec2(0.0, 0.0)
  #   )
  #   return

  self.bounds = rect(
    vec2(
      self.props.x.get(originX) + self.props.xOffset.get(0),
      self.props.y.get(originY) + self.props.yOffset.get(0)
    ),
    vec2(
      self.props.width.get(size.x),
      self.props.height.get(size.y)
    )
  )
  self.scheduleBoundsChangeEventForNextFrame()

proc arrange*(self: Element, rect: Rect): void =
  if not self.isRooted:
    echo "WARN: Tried to arrange an unrooted element: ", self.id
    return

  if not self.isMeasureValid:
    self.measure(rect.size)

  if not(self.isArrangeValid) or not(self.previousArrange.map(x => x == rect).get(false)):
    self.arrangeCore(rect)
    self.isArrangeValid = true
    self.previousArrange = some(rect)

proc childDesiredSizeChanged(self: Element): void =
  if not self.measuring:
    self.invalidateMeasure()

# forward declarations
method measureOverride*(self: Element, availableSize: Vec2[float]): Vec2[float]

proc measureCore(self: Element, availableSize: Vec2[float]): Vec2[float] =
  if self.props.visibility.get(Visibility.Visible) == Visibility.Collapsed:
    # TODO: Make sure this is enough to handle collapsed elements
    # TODO: We can probably also skip a lot of work when collapsed
    # that we are still doing
    return vec2(0.0, 0.0)

  let margin = self.margin()

  let constrained = self.applyLayoutConstraints(availableSize.deflate(margin))
  var
    measured = self.measureOverride(constrained)
    width = self.props.width.get(measured.x)
    height = self.props.height.get(measured.y)


  width = min(width, self.props.maxWidth.get(INF))
  width = max(width, self.props.minWidth.get(0.0))

  height = min(height, self.props.maxHeight.get(INF))
  height = max(height, self.props.minHeight.get(0.0))

  width = min(width, availableSize.x)
  height = min(height, availableSize.y)

  result = vec2(width, height).inflate(margin).nonNegative()

proc measure*(self: Element, availableSize: Vec2[float]): void =
  if not self.isRooted:
    return

  if availableSize.x == NaN or availableSize.y == NaN:
    raise newException(Exception, "Cannot call Measure using a size with NaN values.")

  if not self.isMeasureValid or self.previousMeasure.isNone() or self.previousMeasure.get() != availableSize:
    var previousDesiredSize = self.desiredSize
    var desiredSize = zero()

    self.isMeasureValid = true

    try:
      self.measuring = true
      desiredSize = self.measureCore(availableSize)
    finally:
      self.measuring = false

    self.desiredSize = some(desiredSize)
    self.previousMeasure = some(availableSize)

    if desiredSize != previousDesiredSize and self.parent.isSome():
      self.parent.get().childDesiredSizeChanged()

method measureOverride*(self: Element, availableSize: Vec2[float]): Vec2[float] {.base.} =
  var width = 0.0
  var height = 0.0

  for child in self.children:
    child.measure(availableSize)
    width = max(width, child.desiredSize.get().x)
    height = max(height, child.desiredSize.get().y)

  return vec2(width, height)

proc boundsInWorldSpace*(self: Element): Option[Bounds] =
  self.bounds.map(x => x.withPos(self.actualWorldPosition))

method isPointInside*(self: Element, point: Vec2[float]): bool {.base.} =
  let pos = self.actualWorldPosition
  let size = self.bounds.map(x => x.size).get(zero())
  pos.x < point.x and point.x < pos.x + size.x and pos.y < point.y and point.y < pos.y + size.y

proc relativeTo*(self: Vec2[float], elem: Element): Vec2[float] =
  self.sub(elem.actualWorldPosition)

proc relativeTo*(self: Rect[float], elem: Element): Rect[float] =
  self.withPos(self.pos.relativeTo(elem))

method render*(self: Element): Option[Primitive] {.base.} =
  if self.props.visibility.get(Visibility.Visible) != Visibility.Visible:
    return none[Primitive]()
  if not self.isRooted:
    echo "Not rooted"
    return none[Primitive]()
  if not self.isArrangeValid:
    echo "Arrange not valid"
    return none[Primitive]()

  result = some(
    Primitive(
      transform: self.props.transform,
      bounds: self.bounds.get(),
      clipToBounds: self.props.clipToBounds.get(false),
      kind: PrimitiveKind.Container
    )
  )
  if result.isSome():
    result.get().children = self.children
      .map((x: Element) => x.render())
      .filter((x: Option[Primitive]) => x.isSome())
      .map((x: Option[Primitive]) => x.get())
