import sugar, options
import ../element
import ../types
import ../drawing_primitives
import ../../thickness
import ../../vec
import ../../utils

type
  Text* = ref object of Element
    textProps*: TextProps

# TODO: Remove need for this global
var measureText*: (text: string, fontSize: float, font: string, baseline: string) -> Vec2[float]

method render*(self: Text): Option[Primitive] =
  let props = self.textProps
  some(self.createTextPrimitive(
    props.text,
    props.color.get("white"),
    props.fontSize.get(12.0),
    props.font.get("system-ui"))
  )

method measureOverride(self: Text, avSize: Vec2[float]): Vec2[float] =
  let
    text = self.textProps.text
    # TODO: Put the default text props somewhere
    fontSize = self.textProps.fontSize.get(12.0)
    font = self.textProps.font.get("system-ui")
    # TODO: Adde baseline to TextProps?
    baseline = "top"

  measureText(text, fontSize, font, baseline)

proc createText*(props: TextProps = TextProps(), elemProps: ElemProps = ElemProps()): Text =
  result = Text(
    textProps: props
  )
  initElement(result, elemProps)
