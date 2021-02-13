import options, sugar
import element
import types
import primitives/text
import ../utils
import ../vec

var nativeElementsSingleton*: NativeElements = nil

proc createTextInput*(props: (ElementProps, TextInputProps), children: seq[Element] = @[]): TextInput =
  nativeElementsSingleton.createTextInput(props, children)

  # proc createTextInput*(props: (ElementProps, TextInputProps), children: seq[Element] = @[]): TextInput =
  #   let (elemProps, textProps) = props
  #   cast[TextInput](createText(
  #     (
  #       elemProps,
  #       TextProps(
  #         text: textProps.text,
  #         fontSize: textProps.fontSize,
  #         color: textProps.color,
  #       )
  #     )
  #   ))
