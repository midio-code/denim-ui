import options
import ../element
import ../../vec
import ../../rect
import ../../thickness
import ../../utils

type
  Container* = ref object of Element

method measureOverride(self: Container, availableSize: Vec2[float]): Vec2[float] =
  var accumSize = zero()
  for child in self.children:
    child.measure(vec2(0.0, 0.0))
    let childSize = child.desiredSize.get()
    let childPos = vec2(child.props.x.get(0.0), child.props.y.get(0.0))
    accumSize = accumSize.max(childPos.add(childSize))
  availableSize

method arrangeOverride(self: Container, availableSize: Vec2[float]): Vec2[float] =
  for child in self.children:
    child.arrange(rect(vec2(child.props.x.get(0.0), child.props.y.get(0.0)), child.desiredSize.get(vec2(0.0, 0.0))))
  self.desiredSize.get()

proc container*(props: ElemProps = ElemProps(), children: seq[Element] = @[]): Element =
  result = Container()
  initElement(result, props, children)
