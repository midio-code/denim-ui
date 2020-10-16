import sugar, options
import ../element
import ../types
import ../drawing_primitives
import ../../thickness
import ../../vec
import ../../utils

# TODO: Remove need for this global
var measureText*: (text: string, fontSize: float, font: string, baseline: string) -> Vec2[float]

proc renderText*(self: Element, props: TextProps): Primitive =
  let worldPos = self.actualWorldPosition()
  self.createTextPrimitive(props.text, worldPos, props.color.get("white"), props.fontSize.get(12.0), props.font.get("system-ui"))

proc internalMeasure(element: Element, text: string, fontSize: float, font: string, baseline: string): Vec2[float] =
  measureText(text, fontSize, font, baseline)

proc createText*(props: TextProps = TextProps(), elemProps: ElemProps = ElemProps()): Element =
  newElement(
    props = elemProps,
    layout = some(Layout(
      name: "text(layout)",
      # TODO: Make sure these default values don't mess things up
      measure: (self: Element, avSize: Vec2[float]) => internalMeasure(self, props.text, props.fontSize.get(14.0), props.font.get("system-ui"), "top")
    )),
    drawable = some(Drawable(
      name: "text(render)",
      render: (self: Element) => renderText(self, props)
    ))
  )

proc createText*(text: string, fontSize: float, margin: Thickness[float] = thickness()): Element =
  createText(props = TextProps(text: text, fontSize: fontSize), elemProps = ElemProps(margin: margin))
