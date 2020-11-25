import sugar, options
import ../element
import ../types
import ../drawing_primitives
import ../../thickness
import ../../vec
import ../../utils
import defaults

type
  Text* = ref object of Element
    textProps*: TextProps

# TODO: Remove need for this global
var measureText*: (text: string, fontSize: float, font: string, baseline: string) -> Vec2[float]

method render*(self: Text): Option[Primitive] =
  let props = self.textProps
  some(self.createTextPrimitive(
    props.text,
    props.color.get(colWhite),
    props.fontSize.get(12.0),
    props.font.get(defaults.font))
  )

method measureOverride(self: Text, avSize: Vec2[float]): Vec2[float] =
  let
    text = self.textProps.text
    # TODO: Put the default text props somewhere
    fontSize = self.textProps.fontSize.get(12.0)
    font = self.textProps.font.get(defaults.font)
    # TODO: Adde baseline to TextProps?
    baseline = "top"

  measureText(text, fontSize, font, baseline)

proc initText*(self: Text, props: TextProps): void =
  self.textProps = props

proc createText*(props: (ElementProps, TextProps), children: seq[Element] = @[]): Text =
  let (elemProps, textProps) = props
  result = Text()
  initElement(result, elemProps)
  initText(result, textProps)
