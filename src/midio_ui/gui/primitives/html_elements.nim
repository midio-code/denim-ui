import options, strformat, sugar, dom
import ./text
import ../element
import ../drawing_primitives
import ../types
import ../../vec
import ../../rect
import defaults
import colors

# this.pointerPressed.add((sender, arg) => {
#   if (!this.pointerManager.pointerCaptured) {
#     this.capturePointer()
#     setTimeout(() => elem.focus(), 0)
#     } else if (!this.isPointInside(new Vec2(arg.x, arg.y))) {
#       this.releaseCapture()
#     }
# })
let nativeContainer = getElementById("nativeContainer")
# TODO: Get the correct scaling here
let hardCodedScale = 2.0

type
  HtmlTextInput* = ref object of TextInput
    domElement*: dom.Element

proc updateTextProps(self: HtmlTextInput): void =
  self.domElement.style.color = $self.textInputProps.color.get("black".parseColor())
  self.domElement.style.fontSize = $self.textInputProps.fontSize.get(12.0) & "pt"

proc createHtmlTextInput(props: TextInputProps): dom.Element =
  result = document.createElement("INPUT")
  result.style.position = "absolute"
  # TODO: Remove or replace this: result.updateTextProps(props)
  if props.placeholder.isSome():
    result.setAttribute("placeholder", props.placeholder.get())
  result.value = props.text

method measureOverride(self: HtmlTextInput): Vec2[float] =
  let props = self.textInputProps
  let actualText =
    if props.text == "":
      props.placeholder.get("")
    else:
      props.text

  let measured = measureText(actualText, props.fontSize.get(12.0), props.font.get(defaults.font), "top")
  measured / vec2(2.0, 1.0)

# TODO: We are kind of misusing render here. Create a way to react to layouts instead of using render.
method render(self: HtmlTextInput): Option[Primitive] =
  let props = self.textInputProps
  let scale = vec2(1.0, 1.0)
  let positionScale = vec2(2.0, 2.0) # TODO: Get correct scaling
  let worldPos = self.actualWorldPosition().mul(positionScale)
  let fontSize = props.fontSize.get(12.0) * 2.0
  self.domElement.style.transform = &"translate({worldPos.x}px,{worldPos.y}px) scale({scale.x}, {scale.y})"
  self.domElement.style.background = "none"
  self.domElement.style.border = "none"
  self.domElement.style.width = &"{self.bounds.get().width * 2.0}px"
  self.domElement.style.height = &"{self.bounds.get().height * 2.0}px"
  self.domElement.style.setProperty("font-size", &"{fontSize}px")
  self.updateTextProps()
  if props.text != self.domElement.innerHtml:
    self.domElement.innerHtml = props.text
  none[Primitive]()

method onRooted(self: HtmlTextInput): void =
  nativeContainer.appendChild(self.domElement)

proc unrootHtmlTextInput(self: HtmlTextInput): void =
  nativeContainer.removeChild(self.domElement)

method arrangeOverride(self: HtmlTextInput, availableSize: Vec2[float]): Vec2[float] =
  # self.style.width = &"{availableSize.x}pt"
  # self.style.height = &"{availableSize.y}pt"
  availableSize


proc htmlTextInput*(props: ElementProps, textInputProps: TextInputProps): HtmlTextInput =
  let domElement = createHtmlTextInput(textInputProps)
  result = HtmlTextInput(
    textInputProps: textInputProps,
    domElement: domElement
  )
  initElement(result, props)
