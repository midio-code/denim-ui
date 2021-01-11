import options, sugar
import element
import types
import primitives/text
import ../utils
import ../vec

when defined(js):
  import primitives/html_elements

  proc createTextInput*(props: (ElementProps, TextInputProps), children: seq[Element] = @[]): TextInput =
    let (elemProps, textInputProps) = props
    htmlTextInput(elemProps, textInputProps)

else:
  proc createTextInput*(props: (ElementProps, TextInputProps), children: seq[Element] = @[]): TextInput =
    let (elemProps, textProps) = props
    cast[TextInput](createText(
      (
        elemProps,
        TextProps(
          text: textProps.text,
          fontSize: textProps.fontSize,
          color: textProps.color,
        )
      )
    ))
