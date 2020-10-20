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
    scrollProgress*: Option[Vec2[float]]

proc measureScrollView(self: Element, props: ScrollViewProps, availableSize: Vec2[float]): Vec2[float] =
  for child in self.children:
    child.measure(vec2(0.0, 0.0))
  availableSize


proc arrangeScrollView(self: Element, props: ScrollViewProps, availableSize: Vec2[float]): Vec2[float] =
  let progress = props.scrollProgress.get(vec2(0.0))
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
