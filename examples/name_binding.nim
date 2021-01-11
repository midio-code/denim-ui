import denim_ui
import denim_ui_canvas
import macros

proc render(): Element =
  var elemen1: Element
  expandMacros:
    panel():
      rectangle(color = "red"):
        onClicked(
          proc(e: Element): void =
            echo "E: ", e.id
            echo "Element: ", this.id
        )

startApp(
  render,
  "rootCanvas",
  "nativeContainer"
)
