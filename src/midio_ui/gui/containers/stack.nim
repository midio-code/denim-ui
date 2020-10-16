import options
import ../element
import ../../vec
import ../../rect
import ../../thickness
import ../../utils

type
  StackDirection* = enum
    Vertical, Horizontal
  StackProps* = ref object
    direction*: StackDirection

template cond(cond, a, b: untyped): untyped =
  if cond:
    a
  else:
    b

proc measureStack(self: Element, props: StackProps, availableSize: Vec2[float]): Vec2[float] =
  var width = 0.0
  var accumulatedHeight = 0.0
  let isVertical = props.direction == StackDirection.Vertical
  for child in self.children:
    child.measure(cond(isVertical, availableSize.withY(0.0), availableSize.withX(0.0)))
    if child.desiredSize.isSome():
      width = max(width, cond(isVertical, child.desiredSize.get().x, child.desiredSize.get().y))
      accumulatedHeight += cond(isVertical, child.desiredSize.get().y, child.desiredSize.get().x)
    else:
      echo "WARN: Child of stack did not have a desired size"

  cond(isVertical, vec2(width, accumulatedHeight), vec2(accumulatedHeight, width))

proc arrangeStack(self: Element, props: StackProps, availableSize: Vec2[float]): Vec2[float] =
  var nextPos = vec2(0.0, 0.0)
  let isVertical = props.direction == StackDirection.Vertical
  for child in self.children:
    if child.desiredSize.isSome():
      child.arrange(
        rect(
          nextPos,
          cond(
            isVertical,
            vec2(availableSize.x, child.desiredSize.get().y),
            vec2(child.desiredSize.get().x, availableSize.y)
          )
        )
      )
      nextPos = cond(isVertical, nextPos.addY(child.desiredSize.get().y), nextPos.addX(child.desiredSize.get().x))
    else:
      echo "WARN: Child of stack did not have a desired size"
  self.desiredSize.get()

proc createStack*(stackProps: StackProps, props: ElemProps = ElemProps(), children: seq[Element] = @[]): Element =
  result = newElement(props, children, some(Layout(
    name: "stack",
    measure: proc(elem: Element, avSize: Vec2[float]): Vec2[float] = measureStack(elem, stackProps, avSize),
    arrange: proc(self: Element, availableSize: Vec2[float]): Vec2[float] = arrangeStack(self, stackProps, availableSize)
  )))

# proc createStack*(props: ElemProps = ElemProps(), children: varargs[Element] = @[]): Element =
#   createStack(props, @children)

# proc createStack*(margin: Thickness[float], children: seq[Element] = @[]): Element =
#   createStack(props = ElemProps(margin: margin), children = children)

# proc createStack*(margin: Thickness[float], children: varargs[Element] = @[]): Element =
#   createStack(margin, children = @children)

# proc createStack*(pos: Vec2[float], children: varargs[Element] = @[]): Element =
#   createStack(props = ElemProps(x: pos.x, y: pos.y), children = @children)
