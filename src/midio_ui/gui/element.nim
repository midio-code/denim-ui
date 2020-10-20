import sugar, tables, strformat, options, macros, strutils, sets
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
proc isRooted*(self: Element): bool
proc isRoot*(self: Element): bool
proc measure*(self: Element, availableSize: Vec2[float]): void
proc arrange*(self: Element, rect: Rect): void

type
  LayoutManager = ref object
    toMeasure: HashSet[Element]
    toArrange: HashSet[Element]

proc initLayoutManager*(): LayoutManager =
  LayoutManager(toMeasure: initHashSet[Element](), toArrange: initHashSet[Element]())

let instance = initLayoutManager()

proc measure*(self: LayoutManager, elem: Element, availableSize: Vec2[float]): void =
  if not elem.isRooted():
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
  if not elem.isRooted():
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


# NOTE: Defines: onLayoutPerformed, emitLayoutPerformed and observeLayoutPerformed
createEvent(layoutPerformed, Bounds)

# TODO(important): This is wrong, we cannot use the entire rect as available space for any other element than the root!
proc performOutstandingLayoutsAndMeasures*(rect: Bounds): void =
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

proc size*(props: ElemProps): Option[Vec2[float]] =
  if props.width.isSome() and props.height.isSome():
    some(vec2(props.width.get, props.height.get))
  else:
    none[Vec2[float]]()

proc `size=`*(props: ElemProps, value: Vec2[float]): void =
  props.width = some(value.x)
  props.height = some(value.y)


proc pos*(props: ElemProps): Option[Vec2[float]] =
  if props.width.isSome() and props.height.isSome():
    some(vec2(props.x.get, props.y.get))
  else:
    none[Vec2[float]]()

proc `pos=`*(props: ElemProps, value: Vec2[float]): void =
  props.x = some(value.x)
  props.y = some(value.y)

proc description*(self: Element): string =
  let layoutName = self.layout.map(x => x.name).get("no layout")
  let drawableName = self.drawable.map(x => x.name).get("no drawable")
  &"({layoutName}):({drawableName})"

proc isRoot*(self: Element): bool =
  self.hasTag("root")

proc getRoot*(self: Element): Element =
  if self.isRoot:
    return self
  result = self
  while result.parent.isSome():
    result = result.parent.get()

proc isRooted*(self: Element): bool =
  result = self.getRoot().map(x => x.hasTag("root")).get(false)

proc dispatchOnRooted*(self: Element): void =
  if self.onRooted.isSome():
    self.onRooted.get()(self)
  for child in self.children:
    child.dispatchOnRooted()

proc dispatchOnUnrooted*(self: Element): void =
  if self.onUnrooted.isSome():
    self.onUnrooted.get()(self)
  for child in self.children:
    child.dispatchOnUnrooted()

# TODO: Remove the need for this forward declaration
proc addChild*(self: Element, child: Element): void =
  self.children.add(child)
  child.parent = some(self)
  self.isMeasureValid = false
  self.isArrangeValid = false
  if self.isRooted:
    child.dispatchOnRooted()

proc detachFromParent(self: Element): void =
  self.parent = none[Element]()
  self.dispatchOnUnrooted()

proc removeChild*(self: Element, child: Element): void =
  let index = self.children.find(child)
  if index >= 0:
    self.children.delete(index)
    self.isMeasureValid = false
    self.isArrangeValid = false
    child.detachFromParent()

# TODO: Hide the children field or make this easier to discover
proc setChildren*(self: Element, value: seq[Element]): void =
  for child in self.children:
    child.detachFromParent()
  self.children = @[]
  for child in value:
    self.addChild(child)

proc newElement*(
  props: ElemProps = ElemProps(),
  children: seq[Element] = @[],
  layout: Option[Layout] = none[Layout](),
  drawable: Option[Drawable] = none[Drawable](),
  onRooted: Option[(Element) -> void] = none[(Element) -> void](),
  onUnrooted: Option[(Element) -> void] = none[(Element) -> void](),
  ): Element =
  result = Element(
    id: genGuid(),
    props: props,
    children: children,
    layout: layout,
    drawable: drawable,
    parent: none[Element](),
    onRooted: onRooted,
    onUnrooted: onUnrooted
  )
  for child in children:
    child.parent = result

proc createPanel*(children: varargs[Element]): Element =
  newElement(children = @children)

proc createPanel*(props: ElemProps, children: varargs[Element]): Element =
  newElement(props, @children)

proc createPanel*(props: ElemProps, children: seq[Element]): Element =
  newElement(props, children)

proc createPanel*(margin: Thickness[float], children: varargs[Element]): Element =
  newElement(ElemProps(margin: margin), @children)

proc applyLayoutConstraints*(element: Element, constraints: Vec2[float]): Vec2[float] =
  let elementWidth = element.props.width.get(0)
  let elementHeight = element.props.height.get(0)

  var width = if elementWidth > 0: elementWidth
              else: constraints.x
  var height = if elementHeight > 0: elementHeight
               else: constraints.y

  if (element.props.maxWidth.isSome()):
    width = min(width, element.props.maxWidth.get())
  if (element.props.minWidth.isSome()):
    width = max(width, element.props.minWidth.get())
  if (element.props.maxHeight.isSome()):
    height = min(height, element.props.maxHeight.get(0))
  if (element.props.maxHeight.isSome()):
    height = max(height, element.props.minHeight.get(0))
  vec2(width, height)

proc getTreeDepth(self: Element): int =
  var i = 0
  var p = self.parent
  while p.isSome():
    i += 1
    let parent = p.get()
    if isNil(parent):
      return i
    p = parent.parent
  return i

proc getSpacesForDepth(self: Element): string =
  let depth = self.getTreeDepth()
  return repeat("    ", depth)

proc log*(self: Element, msg: string): void =
  echo self.getSpacesForDepth(), msg

proc printTree*(self: Element, prefix: string = ""): void =
  echo prefix & self.getSpacesForDepth() & self.layout.map(x => x.name).get("element") & &" - {self.id} - " & self.drawable.map(x => x.name).get("x") & " " & $self.bounds.get(rect(0.0, 0.0, 0.0, 0.0))
  for child in self.children:
    child.printTree()

proc `$`*(p: ElemProps): string =
  result = &"props: {$p.x} {$p.y} {$p.width} {$p.height}"

proc `$`*(p: Element): string =
  result = "Elem: " & $p.props

proc margin*(p: Element): Thickness[float] =
  p.props.margin.get(thickness(0.0))


# Forward declaration

proc arrangeOverride*(self: Element, finalSize: Vec2[float]): Vec2[float] =
  if self.layout.filter(x => not(isNil(x.arrange))).isSome():
    self.layout.get().arrange(self, finalSize)
  else:
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
  let horizontalAlignment = self.props.horizontalAlignment.get(HorizontalAlignment.Stretch)
  let verticalAlignment = self.props.verticalAlignment.get(VerticalAlignment.Stretch)
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
    vec2(self.props.x.get(originX) + self.props.xOffset.get(0), self.props.y.get(originY) + self.props.yOffset.get(0)),
    vec2(self.props.width.get(size.x), self.props.height.get(size.y))
  )
  self.emitOnBoundsChanged()

proc arrange*(self: Element, rect: Rect): void =
  if not self.isRooted():
    echo "WARN: Tried to arrange an unrooted element: ", self.id
    return

  if not self.isMeasureValid:
    self.measure(rect.size)

  if not(self.isArrangeValid) or not(self.previousArrange.map(x => x == rect).get(false)):
    self.arrangeCore(rect)
    self.isArrangeValid = true
    self.previousArrange = some(rect)

# forward declarations
proc measureOverride*(self: Element, availableSize: Vec2[float]): Vec2[float]

proc measureCore(self: Element, availableSize: Vec2[float]): Vec2[float] =
  if self.props.visibility.get(Visibility.Visible) == Visibility.Collapsed:
    # TODO: Make sure this is enough to handle collapsed elements
    # TODO: We can probably also skip a lot of work when collapsed
    # that we are still doing
    return vec2(0.0, 0.0)

  let margin = self.margin()

  let constrained = self.applyLayoutConstraints(availableSize.deflate(margin))
  var measured = self.measureOverride(constrained)

  var width = measured.x
  var height = measured.y

  if self.props.width.isSome():
    width = self.props.width.get()
  if self.props.maxWidth.isSome():
    width = min(width, self.props.maxWidth.get())
  if self.props.minWidth.isSome():
    width = max(width, self.props.minWidth.get())
  if self.props.height.isSome():
    height = self.props.height.get()
  if self.props.maxHeight.isSome():
    height = min(height, self.props.maxHeight.get())
  if self.props.minHeight.isSome():
    height = max(height, self.props.minHeight.get())

  result = vec2(width, height).inflate(margin).nonNegative()

proc childDesiredSizeChanged(self: Element): void =
  if not self.measuring:
    self.invalidateMeasure()

proc measure*(self: Element, availableSize: Vec2[float]): void =
  if not self.isRooted():
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

    #if isInvalidSize(desiredSize):
    #throw new Error("Invalid size result =ed for Measure.")

    self.desiredSize = some(desiredSize)
    self.previousMeasure = some(availableSize)

    if desiredSize != previousDesiredSize and self.parent.isSome():
      self.parent.get().childDesiredSizeChanged()

proc measureOverride*(self: Element, availableSize: Vec2[float]): Vec2[float] =
  if self.layout.filter(x => not(isNil(x.measure))).isSome():
    return self.layout.get().measure(self, availableSize)
  else:
    var width = 0.0
    var height = 0.0

    for child in self.children:
      child.measure(availableSize)
      width = max(width, child.desiredSize.get().x)
      height = max(height, child.desiredSize.get().y)

    return vec2(width, height)

proc boundsInWorldSpace*(self: Element): Option[Bounds] =
  self.bounds.map(x => x.withPos(self.actualWorldPosition))

proc isPointInside*(self: Element, point: Vec2[float]): bool =
  let pos = self.actualWorldPosition
  let size = self.bounds.map(x => x.size).get(zero())
  pos.x < point.x and point.x < pos.x + size.x and pos.y < point.y and point.y < pos.y + size.y

proc relativeTo*(self: Vec2[float], elem: Element): Vec2[float] =
  self.sub(elem.actualWorldPosition)

proc relativeTo*(self: Rect[float], elem: Element): Rect[float] =
  self.withPos(self.pos.relativeTo(elem))

