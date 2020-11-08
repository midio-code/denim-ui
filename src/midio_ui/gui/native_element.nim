import options, sugar
import element
import types
import primitives/text
import ../utils
import ../vec

when defined(js):
  import primitives/html_elements

  proc createTextInput*(props: ElementProps, textInputProps: TextInputProps): Element =
    htmlTextInput(props, textInputProps)

else:
  proc createTextInput*(props: ElementProps, textInputProps: TextInputProps): Element =
    createText(
      TextProps(
        text: props.text,
        fontSize: props.fontSize,
        color: props.color,
      )
    )
