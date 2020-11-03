import options
import strformat
import ../dsl/dsl
import ../element_observables
import ../../vec
import ../../rect
import dock
import ../primitives/rectangle
import ../behaviors/onDrag

type
  ScrollViewProps* = ref object
    contentSize*: Subject[Vec2[float]]
    scrollViewSize*: Subject[Vec2[float]]
    scrollProgress*: Option[Vec2[float]]

proc measureScrollView(self: Element, props: ScrollViewProps, availableSize: Vec2[float]): Vec2[float] =
  for child in self.children:
    child.measure(availableSize.withY(INF))
  var largestChild = vec2(0.0)
  for child in self.children:
    largestChild = largestChild.max(child.desiredSize.get())
  if not isNil(props.contentSize) and (isNil(props.contentSize.value) or props.contentSize.value != largestChild):
    props.contentSize.next(largestChild)
  if not isNil(props.scrollViewSize) and (isNil(props.scrollViewSize.value) or props.scrollViewSize.value != availableSize):
    props.scrollViewSize.next(availableSize)

  availableSize

proc arrangeScrollView(self: Element, props: ScrollViewProps, availableSize: Vec2[float]): Vec2[float] =
  let progress = props.scrollProgress.get(vec2(0.0)).clamp(vec2(0.0), vec2(1.0))
  for child in self.children:
    let childSizeOverBounds = max(vec2(0.0), child.desiredSize.get() - availableSize)
    child.arrange(rect(-progress.x * childSizeOverBounds.x, -progress.y * childSizeOverBounds.y, availableSize.x, availableSize.y))
  self.desiredSize.get()

proc createScrollView*(scrollViewProps: ScrollViewProps, props: ElemProps = ElemProps(), children: seq[Element] = @[]): Element =
  result = newElement(props, children, some(Layout(
    name: "scrollView",
    measure: proc(elem: Element, avSize: Vec2[float]): Vec2[float] = measureScrollView(elem, scrollViewProps, avSize),
    arrange: proc(self: Element, availableSize: Vec2[float]): Vec2[float] = arrangeScrollView(self, scrollViewProps, availableSize)
  )))
