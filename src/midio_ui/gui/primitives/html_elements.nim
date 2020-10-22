import options, strformat, sugar, dom
import ../element
import ../drawing_primitives
import ../types
import ../../vec
import ../../rect

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

proc updateTextProps(self: dom.Element, props: TextInputProps): void =
  self.style.color = props.color.get("black")
  self.style.fontSize = $props.fontSize.get(15) & "pt"

proc createHtmlTextInput(props: TextInputProps): dom.Element =
  result = document.createElement("INPUT")
  result.style.position = "absolute"
  result.updateTextProps(props)
  if props.placeholder.isSome():
    result.setAttribute("placeholder", props.placeholder.get())
  result.value = props.text

proc measureHtmlTextInput(self: dom.Element, availableSize: Vec2[float]): Vec2[float] =
  let r = self.getBoundingClientRect()
  let size = vec2(r.width, r.height)
  size.divide(2.0)

# TODO: We are kind of misusing render here. Create a way to react to layouts instead of using render.
proc renderHtmlTextInput(self: dom.Element, owner: element.Element, props: TextInputProps): Option[Primitive] =
  let scale = vec2(1.0, 1.0)
  let positionScale = vec2(2.0, 2.0) # TODO: Get correct scaling
  let worldPos = owner.actualWorldPosition().mul(positionScale)
  self.style.transform = &"translate({worldPos.x}px,{worldPos.y}px) scale({scale.x}, {scale.y})"
  self.updateTextProps(props)
  if props.text != self.innerHtml:
    self.innerHtml = props.text
  none[Primitive]()

proc rootHtmlTextInput(self: dom.Element, owner: element.Element): void =
  nativeContainer.appendChild(self)

proc unrootHtmlTextInput(self: dom.Element, owner: element.Element): void =
  nativeContainer.removeChild(self)

proc arrangeHtmlTextInput(self: dom.Element, owner: element.Element, availableSize: Vec2[float]): Vec2[float] =
  # self.style.width = &"{availableSize.x}pt"
  # self.style.height = &"{availableSize.y}pt"
  availableSize


proc htmlTextInput*(props: TextInputProps): element.Element =
  let domElement = createHtmlTextInput(props)

  # NOTE: HACK to react to the content of the text input changing
  domElement.addEventListener(
    "input",
    proc(ev: dom.Event): void =
      result.invalidateLayout()
      let t = domElement.value
      echo "Got new value: ", t
      if props.onChange.isSome():
        props.onChange.get()($t)
  )
  result = newElement(
    layout = some(Layout(
      name: "textInput(layout)",
      measure: (self: element.Element, avSize: Vec2[float]) => domElement.measureHtmlTextInput(avSize),
      arrange: (self: element.Element, avSize: Vec2[float]) => domElement.arrangeHtmlTextInput(self, avSize)
    )),
    drawable = some(Drawable(
      name: "textInput(drawable)",
      render: (self: element.Element) => domElement.renderHtmlTextInput(self, props),
    )),
    onRooted = some((self: element.Element) => domElement.rootHtmlTextInput(self)),
    onUnrooted = some((self: element.Element) => domElement.unrootHtmlTextInput(self)),
  )
