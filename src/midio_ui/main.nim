import sugar, options, strformat
import gui/prelude
import gui/primitives/text
import gui/update_manager
import gui/debug/debug_tree
import std/monotimes

type
  Context* = ref object
    render*: (Context, float) -> Option[Primitive]
    dispatchPointerMove*: (x: float, y: float) -> void
    dispatchPointerDown*: (x: float, y: float) -> void
    dispatchPointerUp*: (x: float, y: float) -> void
    dispatchKeyDown*: (code: int, key: string) -> void
    dispatchWindowSizeChanged*: (newSize: Vec2[float]) -> void
    dispatchUpdate*: (float) -> void
    rootElement*: prelude.Element
    scale*: Vec2[float]
    size*: Vec2[float]

proc setParentOnChildren(elem: prelude.Element): void =
  for child in elem.children:
    child.parent = some(elem)
    child.setParentOnChildren()

var pointerPosChangedThisFrame = false
var lastPointerPos = vec2(0.0, 0.0)

var pointerPressedLastFrame = false
var pointerPressedThisFrame = false

var windowSize: Vec2[float]

proc scaleMousePos(ctx: Context, pos: Vec2[float]): Vec2[float] =
  vec2(pos.x / ctx.scale.x, pos.y / ctx.scale.y)

var samples = 0
var startTime = float(getMonoTime().ticks) / 1000000.0
proc render*(ctx: Context, dt: float): Option[Primitive] {.exportc.} =

  let availableRect = rect(zero(), windowSize.divide(ctx.scale))
  performOutstandingLayoutsAndMeasures(availableRect)

  # NOTE: This must be called before each frame
  invalidateWorldPositionsCache()

  if pointerPosChangedThisFrame:
    ctx.rootElement.dispatchPointerMove(pointerArgs(ctx.rootElement, ctx.scaleMousePos(lastPointerPos)))
    pointerPosChangedThisFrame = false

  if pointerPressedLastFrame == false and pointerPressedThisFrame == true:
    ctx.rootElement.dispatchPointerDown(pointerArgs(ctx.rootElement, ctx.scaleMousePos(lastPointerPos)))
    pointerPressedLastFrame = true

  if pointerPressedLastFrame == true and pointerPressedThisFrame == false:
    ctx.rootElement.dispatchPointerUp(pointerArgs(ctx.rootElement, ctx.scaleMousePos(lastPointerPos)))
    pointerPressedLastFrame = false

  update_manager.dispatchUpdate(dt)
  performOutstandingLayoutsAndMeasures(availableRect)

  result = ctx.rootElement.render()

  samples += 1
  if samples >= 60:
    let currentTime = float(getMonoTime().ticks) / 1000000.0
    echo &"MS/frame: {float(currentTime - startTime)/60.0}"
    samples = 0
    startTime = currentTime


proc dispatchWindowSizeChanged*(newSize: Vec2[float]): void {.exportc.} =
  windowSize = newSize

proc dispatchPointerMove*(x: float, y: float): void {.exportc.} =
  if (lastPointerPos.x != x or lastPointerPos.y != y) and pointerPosChangedThisFrame == false:
    pointerPosChangedThisFrame = true
    lastPointerPos = vec2(x, y)

proc dispatchPointerPress*(x: float, y: float): void {.exportc.} =
  lastPointerPos = vec2(x, y)
  pointerPressedThisFrame = true

proc dispatchPointerRelease*(x: float, y: float): void {.exportc.} =
  lastPointerPos = vec2(x, y)
  pointerPressedThisFrame = false

proc dispatchKeyDown*(keyCode: int, key: string): void {.exportc.} =
  keyDownEmitter.emit(
    KeyArgs(
      key: key, # TODO: We seem to be gettin the wrong key
      keyCode: keyCode
    )
  )

proc init*(
  size: Vec2[float],
  scale: Vec2[float],
  measureTextFunction: (string, float, string, string) -> Vec2[float],
  render: () -> Element
): Context {.exportc.} =
  text.measureText = measureTextFunction
  windowSize = size
  let rootElement =
    render()

  rootElement.addTag("root")
  rootElement.setParentOnChildren()
  rootElement.dispatchOnRooted()
  rootElement.invalidateLayout()
  result = Context(
    rootElement: rootElement,
    dispatchPointerMove: dispatchPointerMove,
    dispatchPointerDown: dispatchPointerPress,
    dispatchPointerUp: dispatchPointerRelease,
    dispatchKeyDown: dispatchKeyDown,
    dispatchWindowSizeChanged: dispatchWindowSizeChanged,
    scale: scale,
    size: size,
  )

proc nim_interop_test() {.exportc.}=
  echo "Hello, world. From nim."
