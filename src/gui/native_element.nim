import options
import sugar
import element
import ../utils
import ../vec
import types
import text

when defined(js):
  import html_elements

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
