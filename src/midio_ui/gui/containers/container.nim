import options
import ../element
import ../../vec
import ../../rect
import ../../thickness
import ../../utils

proc measureContainer(self: Element, availableSize: Vec2[float]): Vec2[float] =
  var accumSize = zero()
  for child in self.children:
    child.measure(vec2(0.0, 0.0))
    let childSize = child.desiredSize.get()
    let childPos = vec2(child.props.x.get(0.0), child.props.y.get(0.0))
    accumSize = accumSize.max(childPos.add(childSize))
  availableSize

proc arrangeContainer(self: Element, availableSize: Vec2[float]): Vec2[float] =
  for child in self.children:
    child.arrange(rect(vec2(child.props.x.get(0.0), child.props.y.get(0.0)), child.desiredSize.get(vec2(0.0, 0.0))))
  self.desiredSize.get()

proc containerLayout*(): Layout =
  Layout(
    name: "container",
    measure: measureContainer,
    arrange: arrangeContainer
  )

proc container*(props: ElemProps = ElemProps(), children: seq[Element] = @[]): Element =
  result = newElement(props, children)
  result.layout = some(containerLayout())

proc container*(margin: Thickness[float], children: seq[Element] = @[]): Element =
  container(ElemProps(margin: margin), children)

proc container*(margin: Thickness[float], children: varargs[Element] = @[]): Element =
  container(ElemProps(margin: margin), @children)

proc container*(children: varargs[Element] = @[]): Element =
  container(props = ElemProps(), children = @children)
