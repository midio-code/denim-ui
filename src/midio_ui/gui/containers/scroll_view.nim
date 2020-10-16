
import options
import ../element
import ../../vec
import ../../rect
import ../../thickness
import ../../utils

type
  ScrollViewDirection* = enum
    Vertical
    Horizontal
  ScrollViewProps* = ref object
    allowedScrollDirections*: ScrollViewDirection

proc measureScrollView(self: Element, props: ScrollViewProps, availableSize: Vec2[float]): Vec2[float] =
  for child in self.children:
    child.measure(vec2(0.0, 0.0))
  availableSize


proc arrangeScrollView(self: Element, props: ScrollViewProps, availableSize: Vec2[float]): Vec2[float] =
  for child in self.children:
    child.arrange(rect(0.0, 0.0, availableSize.x, availableSize.y))
  self.desiredSize.get()

proc createScrollView*(scrollViewProps: ScrollViewProps, props: ElemProps = ElemProps(), children: seq[Element] = @[]): Element =
  result = newElement(props, children, some(Layout(
    name: "scrollView",
    measure: proc(elem: Element, avSize: Vec2[float]): Vec2[float] = measureScrollView(elem, scrollViewProps, avSize),
    arrange: proc(self: Element, availableSize: Vec2[float]): Vec2[float] = arrangeScrollView(self, scrollViewProps, availableSize)
  )))
