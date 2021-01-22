import options, strformat, sugar, dom
import ./text
import ../element
import ../drawing_primitives
import ../types
import ../../vec
import ../../rect
import defaults
import colors

# TODO: Move all this stuff to the canvas renderer

var nativeContainer: dom.Element = nil

proc getNativeContainer(): dom.Element =
  if isNil(nativeContainer):
    nativeContainer = getElementById("nativeContainer")
  nativeContainer

# TODO: Get the correct scaling here
let hardCodedScale = 2.0

type
  HtmlTextInput* = ref object of TextInput
    domElement*: dom.Element

proc updateTextProps(self: HtmlTextInput): void =
  let props = self.textInputProps
  let positionScale = vec2(hardCodedScale) # TODO: Get correct scaling
  let bounds = self.worldBoundsExpensive()
  let fontSize = props.fontSize.get(defaults.fontSize) * 2.0
  let pos = bounds.pos * positionScale
  self.domElement.style.transform = &"translate({pos.x}px,{pos.y}px)"
  self.domElement.style.background = "none"
  self.domElement.style.width = &"{bounds.width * hardCodedScale}px"
  self.domElement.style.height = &"{bounds.height * hardCodedScale}px"
  self.domElement.style.padding = &"0 0 0 0"
  self.domElement.style.margin = &"0 0 0 0"
  self.domElement.style.color = $self.textInputProps.color.get("black".parseColor())
  self.domElement.style.fontSize = &"{fontSize}px"
  if props.text != self.domElement.innerHtml:
    self.domElement.innerHtml = props.text

proc createHtmlTextInput(props: TextInputProps): dom.Element =
  result = document.createElement("INPUT")
  result.style.position = "absolute"
  # TODO: Remove or replace this: result.updateTextProps(props)
  if props.placeholder.isSome():
    result.setAttribute("placeholder", props.placeholder.get())
  result.value = props.text

method measureOverride(self: HtmlTextInput, availableSize: Vec2[float]): Vec2[float] =
  let props = self.textInputProps
  let actualText =
    if props.text == "":
      props.placeholder.get("")
    else:
      props.text

  measureText(actualText, props.fontSize.get(12.0), props.font.get(defaults.font), "top")

# TODO: We are kind of misusing render here. Create a way to react to layouts instead of using render.
method render(self: HtmlTextInput): Option[Primitive] =
  self.updateTextProps()
  none[Primitive]()

method onRooted(self: HtmlTextInput): void =
  getNativeContainer().appendChild(self.domElement)

method onUnrooted(self: HtmlTextInput): void =
  getNativeContainer().removeChild(self.domElement)

# method arrangeOverride(self: HtmlTextInput, availableSize: Vec2[float]): Vec2[float] =
#   availableSize


proc htmlTextInput*(props: ElementProps, textInputProps: TextInputProps): HtmlTextInput =
  let domElement = createHtmlTextInput(textInputProps)
  domElement.addEventListener(
    "input",
    proc(ev: dom.Event): void =
      if textInputProps.onChange.isSome():
        textInputProps.onChange.get()($ev.target.value)
  )
  result = HtmlTextInput(
    textInputProps: textInputProps,
    domElement: domElement
  )
  initElement(result, props)
