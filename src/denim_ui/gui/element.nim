import sugar, tables, strformat, options, macros, strutils, sets, sequtils, algorithm, math
import rx_nim
import ../vec
import ../rect
import ../mat
import ../transform
import ../thickness
import ../utils
import ../guid
import drawing_primitives
import element_bounds_changed_event
import ../events
import types
import world_position
import tag

export types

# TODO: Move this stuff to own module
var renderCache* = initTable[Element, Primitive]()

proc isChildOf*(child, parent: Element): bool =
  parent.children.find(child) != -1 and  child.parent.isSome and child.parent.get() == parent

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

proc ancestorsDebugString*(self: Element): string =
  var ancestors = ""
  var parent = self.parent
  while parent.isSome:
    ancestors = ancestors & " <- " & parent.get.typeName
    parent = parent.get.parent
  self.typeName & " <- " & ancestors

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
      echo "WARN: Tried to arrange element without a desired size."

proc performOutstandingMeasure(self: LayoutManager, availableSize: Vec2[float]): void =
  while self.toMeasure.len() > 0:
    let elem = self.toMeasure.pop()
    self.measure(elem, availableSize)

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

proc invalidateVisual*(self: Element): void =
  self.isVisualValid = false
  if self in renderCache:
    renderCache.del(self)
  if self.parent.isSome:
    self.parent.get.invalidateVisual()

proc invalidateArrange(self: Element): void =
  self.isArrangeValid = false
  if self.isRooted:
    instance.toArrange.incl(self)

proc invalidateMeasure(self: Element): void =
  self.isMeasureValid = false
  if self.isRooted:
    instance.toMeasure.incl(self)
  self.invalidateArrange()


proc invalidateLayout*(self: Element): void =
  self.invalidateMeasure()
  self.invalidateVisual()

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


type RootState* {.pure.} = enum
  Unrooted, Rooted, WillUnroot

let isRootedObservables = newTable[Element, Subject[RootState]]()

proc observeIsRooted*(self: Element): Observable[RootState] =
  isRootedObservables.mgetorput(self, behaviorSubject(if self.isRooted: RootState.Rooted else: RootState.Unrooted)).source

method onRooted*(self: Element): void {.base.} =
  discard

method onUnrooted*(self: Element): void {.base.} =
  discard

let beforeUnrootTasks = newTable[Element, seq[(Element, () -> void) -> void]]()
proc beforeUnroot*(self: Element, task: (Element, () -> void) -> void): void =
  beforeUnrootTasks.mgetorput(self, @[]).add(task)

proc clearUnrootTasks(self: Element): void =
  if self in beforeUnrootTasks:
    beforeUnrootTasks.del(self)

proc dispatchOnRooted*(self: Element): void =
  self.isRooted = true
  if self in isRootedObservables:
    isRootedObservables[self] <- RootState.Rooted
  self.onRooted()
  for child in self.children:
    child.dispatchOnRooted()

proc dispatchOnUnrooted*(self: Element): void =
  self.isRooted = false
  # NOTE: In case we get unrooted by a parent, we need to
  # remove any before unroot tasks so that they don't pile up if the
  # item gets rooted again
  # TODO: We might want to make sure the tasks get run in this case as well,
  # but since the before unroot tasks are built to be able to delay
  # actual unrooting, this is a bit more involved than just
  # calling all the before unroot tasks.
  # see issue: https://github.com/nortero-code/midio/issues/86
  self.clearUnrootTasks()
  for child in self.children:
    child.dispatchOnUnrooted()
  self.onUnrooted()

proc detachFromParent(self: Element): void =
  if self.parent.isSome:
    let parent = self.parent.get()
    let index = parent.children.find(self)
    if index != -1:
      parent.children.delete(index)
    self.parent = none[Element]()
    parent.invalidateLayout()

proc finishUnrooting*(self: Element): void =
  if self in isRootedObservables:
    isRootedObservables[self] <- RootState.Unrooted

  self.detachFromParent()
  self.dispatchOnUnrooted()

proc performUnroot(self: Element): void =
  ## Makes sure we run any tasks that should be run before the unroot actually happens.
  ## This lets us for example animate elements out of view before they are removed from the visual tree.
  if self in isRootedObservables:
    isRootedObservables[self] <- RootState.WillUnroot
  if self in beforeUnrootTasks:
    var tasks = beforeUnrootTasks[self]
    if tasks.len > 0:
      var tasksLeft = tasks.len
      for t in tasks:
        t(
          self,
          proc(): void =
            tasksLeft -= 1
            if tasksLeft == 0:
              self.finishUnrooting()
        )
      return
  self.finishUnrooting()

# TODO: Remove the need for this forward declaration
proc addChild*(self: Element, child: Element): void =
  self.children.add(child)
  child.parent = some(self)
  self.invalidateLayout()
  if self.isRooted or self.isRoot:
    child.dispatchOnRooted()

proc insertChild*(self: Element, child: Element, pos: int): void =
  self.children.insert(child, pos)
  child.parent = some(self)
  self.invalidateLayout()
  if self.isRooted or self.isRoot:
    child.dispatchOnRooted()

proc moveChild*(self: Element, child: Element, toIndex: int): void =
  let index = self.children.find(child)
  self.children.delete(index)
  self.children.insert(child, toIndex)
  self.invalidateLayout()

proc removeChild*(self: Element, child: Element): void =
  if child.isChildOf(self):
    child.performUnroot()

proc initElement*(
  self: Element,
  props: ElementProps = ElementProps(),
): void =
  let id = genGuid()
  self.id = id
  self.cachedHashOfId = id.hash()
  self.props = props

proc addChildren*(self: Element, children: seq[Element]): void =
  for child in children:
    self.addChild(child)

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

  let newBounds = rect(
    vec2(
      # NOTE: Flooring here as a way of snapping to pixel
      (self.props.x.get(originX) + self.props.xOffset.get(0)).floor(),
      (self.props.y.get(originY) + self.props.yOffset.get(0)).floor()
    ),
    vec2(
      self.props.width.get(size.x),
      self.props.height.get(size.y)
    )
  )
  if self.bounds != newBounds:
    if self in renderCache:
      renderCache.del(self)
    self.bounds = newBounds
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
  # TODO: We need to be able to measure unrooted elements sometimes;
  # figure out if this can cause trouble (commenting out for now)
  # if not self.isRooted:
  #   return

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

method isPointInside*(self: Element, point: Vec2[float]): bool {.base.} =
  let pos = self.actualWorldPosition
  let size = self.bounds.map(x => x.size).get(zero())
  pos.x < point.x and point.x < pos.x + size.x and pos.y < point.y and point.y < pos.y + size.y

proc relativeTo*(self: Vec2[float], elem: Element): Vec2[float] =
  self.sub(elem.actualWorldPosition)

proc relativeTo*(self: Rect[float], elem: Element): Rect[float] =
  self.withPos(self.pos.relativeTo(elem))

proc compareElementZIndices(a, b: Element): int =
  b.props.zIndex.get - a.props.zIndex.get

proc childrenSortedByZIndex*(self: Element): seq[Element] =
  self
    .children
    .sorted(
       proc(a, b: Element): int =
         b.props.zIndex.get(self.children.find(b)) - a.props.zIndex.get(self.children.find(a))
      ,
      SortOrder.Descending
    )

proc childrenSortedByZIndexReverse*(self: Element): seq[Element] =
  self.childrenSortedByZIndex.reversed

method render*(self: Element): Option[Primitive] {.base.} =
  if not self.isArrangeValid:
    echo "Arrange not valid for: ", self.typeName()
    echo "   parent: ", self.parent.get().typeName()
    return none[Primitive]()
  result = some(
    Primitive(
      id: genGuid().hash(),
      cache: self.props.cacheVisual.get(false),
      transform: self.props.transform,
      bounds: self.bounds.get(),
      clipToBounds: self.props.clipToBounds.get(false),
      kind: PrimitiveKind.Container,
      opacity: self.props.opacity
    )
  )

var beforeRender = emitter[void]()
proc addBeforeRenderListener*(listener: EventHandler[void]): Dispose =
  if not beforeRender.contains(listener):
    beforeRender.add(listener)
    return proc() =
             if beforeRender.contains(listener):
              beforeRender.remove(listener)
  return proc(): void =
    discard

proc dispatchBeforeRenderEvent*() =
  beforeRender.emit()

proc dispatchRender*(self: Element): Option[Primitive] =
  if self in renderCache:
    return some(renderCache[self])

  if self.props.visibility.get(Visibility.Visible) != Visibility.Visible:
    return none[Primitive]()
  if not self.isRooted:
    echo "Not rooted"
    return none[Primitive]()

  result = self.render()

  if result.isSome:
    self.isVisualValid = true
    renderCache[self] = result.get

  if result.isSome() and result.get.children.len == 0:
    var children = newSeqOfCap[Primitive](self.children.len)
    for element in self.childrenSortedByZIndex:
      let primitives = element.dispatchRender()
      if primitives.isSome:
        children.add(primitives.get)
    result.get.children = children

proc transformOnlyBy*(point: Vec2[float], elem: Element): Vec2[float] =
  ## Transforms point by the transform of the given element
  let relativePoint = point.relativeTo(elem)
  let diff = point - relativePoint
  relativePoint.transformInv(elem.props.transform) + diff


proc transformFromRootElem*(self: Point, elem: Element): Point =
  ## Transforms a point by all transforms given by the ancestorys of Element,
  ## taking it from the root space to the local space of the given element.
  var a = self
  if elem.parent.isSome():
    a = self.transformFromRootElem(elem.parent.get())
  a.transformInv(elem.props.transform)


type BoundsAndScale = ref object
  bounds*: Bounds
  scale*: Vec2[float]

proc worldBoundsExpensive*(elem: Element): BoundsAndScale =

  var transformMatrix = mat.identity()
  var currentElem = some(elem)
  while currentElem.isSome():
    let e = currentElem.get
    if e == elem:
      # NOTE: We don't add the x,y coords of the first element as it is taken care
      # of when we apply the transformation matrix
      transformMatrix = e.props.transform.get(@[]).toMatrix * transformMatrix
    else:
      transformMatrix = transform.translation(e.bounds.get(rect(0.0)).pos).toMatrix * e.props.transform.get(@[]).toMatrix * transformMatrix
    currentElem = e.parent

  var b = elem.bounds.get(rect(0.0))
  let tl = transformMatrix * vec2(b.left, b.top)
  let br = transformMatrix * vec2(b.right, b.bottom)
  result = BoundsAndScale(
    bounds: rectFromPoints(
      tl,
      br,
    ),
    scale: transformMatrix.scale
  )

proc dumpTree*(root: Element): string =
  result = ""
  proc visit(element: Element, depth: int = 0) =
    result &= repeat("│ ", depth)
    result &= $element
    result &= "\n"
    for child in element.children:
      visit(child, depth + 1)

  visit(root)
