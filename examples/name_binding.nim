import denim_ui
import denim_ui_canvas
import colors

proc render(): Element =
  panel():
    rectangle(color = colRed)

startApp(
  render,
  "rootCanvas",
  "nativeContainer"
)
