import options
import element
import drawing_primitives
import debug_draw

proc render*(self: Element): seq[Primitive] =
  if self.props.visibility.get(Visibility.Visible) == Visibility.Collapsed:
    return @[]

  if self.drawable.isSome():
    if self.isRooted:
      result = self.drawable.get().render(self)
  for child in self.children:
    result = result & child.render()
  let debugDrawings = flushDebugDrawings()
  result = result & debugDrawings
