import options, sequtils, sugar
import element
import drawing_primitives
import debug_draw

proc render*(self: Element): Option[Primitive] =
  if self.props.visibility.get(Visibility.Visible) != Visibility.Visible:
    return none[Primitive]()
  if self.drawable.isSome() and self.isRooted:
    result = self.drawable.get().render(self)
  else:
    result = some(
      Primitive(
        bounds: self.bounds.get(),
        kind: PrimitiveKind.Container
      )
    )
  if result.isSome():
    result.get().children = self.children.map(x => x.render()).filter(x => x.isSome()).map(x => x.get()) & flushDebugDrawings()
