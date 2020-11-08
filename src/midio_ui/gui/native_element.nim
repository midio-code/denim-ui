import options, sugar
import element
import types
import primitives/text
import ../utils
import ../vec

when defined(js):
  import primitives/html_elements

  proc createTextInput*(props: (ElementProps, TextInputProps), children: seq[Element] = @[]): Element =
    let (elemProps, textInputProps) = props
    htmlTextInput(elemProps, textInputProps)

else:
  proc createTextInput*(props: (ElementProps, TextInputProps), children: seq[Element] = @[]): Element =
    let (elemProps, textProps) = props
    createText(
      (
        elemProps,
        TextProps(
          text: textProps.text,
          fontSize: textProps.fontSize,
          color: textProps.color,
        )
      )
    )
