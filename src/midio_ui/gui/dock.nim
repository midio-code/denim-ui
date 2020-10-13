import sugar
import tables
import options
import sequtils
import element
import ../guid
import ../vec
import ../thickness
import ../rect

type
  DockDirection* {.pure.} = enum
    Default, Left, Top, Right, Bottom

  Docking* = tuple
    elem: Element
    dir: DockDirection

  DockChildren* = seq[Docking]

var intrinsicDockProps = initTable[Guid, DockDirection]()

proc setDocking*(elem: Element, dir: DockDirection): void =
  intrinsicDockProps[elem.id] = dir

proc getDocking*(elem: Element): Option[DockDirection] =
  if intrinsicDockProps.hasKey(elem.id):
    some(intrinsicDockProps[elem.id])
  else:
    none[DockDirection]()

# TODO: See if this step is unnecessary
proc measureDock(self: Element, constraint: Vec2[float]): Vec2[float] =
  var parentWidth = 0.0    # Our current required width due to children thus far.
  var parentHeight = 0.0   # Our current required height due to children thus far.
  var accumulatedWidth = 0.0   # Total width consumed by children.
  var accumulatedHeight = 0.0  # Total height consumed by children.

  var i = -1
  var prevDockDir: DockDirection

  for child in self.children:
    i += 1
    # Child constraint is the remaining size; this is total size minus size consumed by previous children.
    let childConstraint = vec2(
      max(0.0, constraint.x - accumulatedWidth),
      max(0.0, constraint.y - accumulatedHeight)
    )

    # Measure child.
    child.measure(childConstraint)
    let childDesiredSize = child.desiredSize.get() # TODO: Remove ! operator

    # Now, we adjust:
    # 1. Size consumed by children (accumulatedSize).  This will be used when computing subsequent
    #    children to determine how much space is remaining for them.
    # 2. Parent size implied by this child (parentSize) when added to the current children (accumulatedSize).
    #    This is different from the size above in one respect: A Dock.Left child implies a height, but does
    #    not actually consume any height for subsequent children.
    # If we accumulate size in a given dimension, the next child (or the end conditions after the child loop)
    # will deal with computing our minimum size (parentSize) due to that accumulation.
    # Therefore, we only need to compute our minimum size (parentSize) in dimensions that this child does
    #   not accumulate: Width for Top/Bottom, Height for Left/Right.
    let dockDir = getDocking(child)
    if dockDir.isSome():
      case dockDir.get():
      of DockDirection.Left, DockDirection.Right:
        parentHeight = max(parentHeight, accumulatedHeight + childDesiredSize.y)
        accumulatedWidth += childDesiredSize.x
      of DockDirection.Top, DockDirection.Bottom:
        parentWidth = max(parentWidth, accumulatedWidth + childDesiredSize.x)
        accumulatedHeight += childDesiredSize.y
      else: discard

    if i == self.children.len() - 1 and dockDir.get(DockDirection.Default) == DockDirection.Default:
      case prevDockDir:
      of DockDirection.Left, DockDirection.Right:
        parentHeight = max(parentHeight, accumulatedHeight + childDesiredSize.y)
        accumulatedWidth += childDesiredSize.x
      of DockDirection.Top, DockDirection.Bottom:
        accumulatedHeight += childDesiredSize.y
        parentWidth = max(parentWidth, accumulatedWidth + childDesiredSize.x)
      else: discard

    prevDockDir = dockDir.get(prevDockDir)

  # Make sure the final accumulated size is reflected in parentSize.
  parentWidth = max(parentWidth, accumulatedWidth)
  parentHeight = max(parentHeight, accumulatedHeight)

  vec2(parentWidth, parentHeight)

proc arrangeDock(self: Element, arrangeSize: Vec2[float]): Vec2[float] =
  var accumulatedLeft = 0.0
  var accumulatedTop = 0.0
  var accumulatedRight = 0.0
  var accumulatedBottom = 0.0

  let nonFillChildrenCount = self.children.len() - 1

  var i = -1
  for child in self.children:
    i += 1
    let childDesiredSize = child.desiredSize.get() # TODO: Remove ! operator

    var childRect = rect(
      vec2(
        accumulatedLeft,
        accumulatedTop
      ),
      vec2(
        max(0.0, arrangeSize.x - (accumulatedLeft + accumulatedRight)),
        max(0.0, arrangeSize.y - (accumulatedTop + accumulatedBottom))
      )
    )
    let dock = getDocking(child) # rename to getDock
    if i < nonFillChildrenCount and dock.isSome():
      case dock.get():
      of DockDirection.Left:
        accumulatedLeft += childDesiredSize.x
        childRect = childRect.withWidth(childDesiredSize.x)
      of DockDirection.Right:
        accumulatedRight += childDesiredSize.x
        childRect = childRect.withX(max(0.0, arrangeSize.x - accumulatedRight))
        childRect = childRect.withWidth(childDesiredSize.x)
      of DockDirection.Top:
        accumulatedTop += childDesiredSize.y
        childRect = childRect.withHeight(childDesiredSize.y)
      of DockDirection.Bottom:
        accumulatedBottom += childDesiredSize.y
        childRect = childRect.withY(max(0.0, arrangeSize.y - accumulatedBottom))
        childRect = childRect.withHeight(childDesiredSize.y)
      else: discard

    child.arrange(childRect)
    if i >= nonFillChildrenCount:
      accumulatedLeft = min(accumulatedLeft, child.bounds.get().left())
      accumulatedRight = max(accumulatedRight, child.bounds.get().right())
      accumulatedTop = min(accumulatedTop, child.bounds.get().top())
      accumulatedBottom = max(accumulatedBottom, child.bounds.get().bottom())

  arrangeSize.max(
    vec2(accumulatedRight, accumulatedBottom)
  )

## Basic sock panel where one can dock elements to each side, gradually shrinking the
## available space that is used to place the next child.
## Note that the last child can be made to fill the remaining space
## by not assigning it a dock value.
proc createDock*(props: ElemProps, children: seq[Element]): Element =
  result = newElement(
    props,
    children,
    some(Layout(
      name: "dock",
      measure: measureDock,
      arrange: arrangeDock
    ))
  )

proc createDock*(dockings: seq[Docking], elemProps: ElemProps = ElemProps()): Element =
  let children = dockings.map((c) => c.elem)
  for x in dockings:
    echo "Setting dock: ", x.dir
    setDocking(x.elem, x.dir)
  createDock(elemProps, children)

proc createDock*(children: varargs[Docking] = @[]):  Element =
  createDock(@children)

proc createDock*(margin: Thickness[float], children: varargs[Docking] = @[]): Element =
  createDock(@children, elemProps = ElemProps(margin: some(margin)))

proc createDock*(elemProps: ElemProps, children: varargs[Docking] = @[]): Element =
  createDock(@children, elemProps = elemProps)

proc left*(element: Element): Docking =
  (element, DockDirection.Left)

proc top*(element: Element): Docking =
  (element, DockDirection.Top)

proc right*(element: Element): Docking =
  (element, DockDirection.Right)

proc bottom*(element: Element): Docking =
  (element, DockDirection.Bottom)
