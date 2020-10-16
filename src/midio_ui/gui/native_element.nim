import options, sugar
import element
import types
import primitives/text
import ../utils
import ../vec

when defined(js):
  import primitives/html_elements

  proc createTextInput*(props: TextInputProps): Element =
    htmlTextInput(props)

  proc createTextInput*(text: string, onChange: TextChanged): Element =
    createTextInput(
      TextInputProps(
        text: text,
        onChange: onChange
      )
    )

else:
  proc createTextInput*(props: TextInputProps): Element =
    createText(
      TextProps(
        text: props.text,
        fontSize: props.fontSize,
        color: props.color,
      )
    )

  proc createTextInput*(text: string, onChange: TextChanged): Element =
    createText(
      TextProps(
        text: text
      )
    )
