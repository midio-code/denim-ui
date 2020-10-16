import options, sequtils, sugar
import element
import drawing_primitives
import debug_draw

proc render*(self: Element): Primitive =
  if self.props.visibility.get(Visibility.Visible) != Visibility.Visible:
    return Primitive(
      bounds: self.bounds.get(),
      kind: PrimitiveKind.Container
    )
  if self.drawable.isSome() and self.isRooted:
    result = self.drawable.get().render(self)
  else:
    result = Primitive(
      bounds: self.bounds.get(),
      kind: PrimitiveKind.Container
    )
  result.children = self.children.map(x => x.render()) & flushDebugDrawings()
