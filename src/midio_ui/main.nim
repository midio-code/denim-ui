import sugar
import vec
import rect
import gui/prelude
import gui/update_manager
import gui/debug/debug_tree
import events
import options
import observables/observables
import utils
import gui/text
#import app/workspace

type
  Context* = ref object
    render*: (Context, float) -> seq[Primitive]
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

var windowSize: Subject[Vec2[float]]

proc scaleMousePos(ctx: Context, pos: Vec2[float]): Vec2[float] =
  vec2(pos.x / ctx.scale.x, pos.y / ctx.scale.y)

proc render*(ctx: Context, dt: float): seq[Primitive] {.exportc.} =
  if pointerPosChangedThisFrame:
    ctx.rootElement.dispatchPointerMove(pointerArgs(ctx.rootElement, ctx.scaleMousePos(lastPointerPos)))
    pointerPosChangedThisFrame = false

  if pointerPressedLastFrame == false and pointerPressedThisFrame == true:
    ctx.rootElement.dispatchPointerDown(pointerArgs(ctx.rootElement, ctx.scaleMousePos(lastPointerPos)))
    pointerPressedLastFrame = true

  if pointerPressedLastFrame == true and pointerPressedThisFrame == false:
    ctx.rootElement.dispatchPointerUp(pointerArgs(ctx.rootElement, ctx.scaleMousePos(lastPointerPos)))
    pointerPressedLastFrame = false

  #echo "Performing layout with: ", windowSize.value
  let availableRect = rect(zero(), windowSize.value.divide(ctx.scale))
  #echo "Available rect: ", availableRect
  performOutstandingLayoutsAndMeasures(availableRect)

  ctx.dispatchUpdate(dt)
  ctx.rootElement.render()

proc dispatchWindowSizeChanged*(newSize: Vec2[float]): void {.exportc.} =
  windowSize.next(newSize)

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

proc dispatchUpdate*(dt: float): void =
  update_manager.dispatchUpdate(dt)

proc init*(
  size: Vec2[float],
  scale: Vec2[float],
  measureTextFunction: (string, float, string, string) -> Vec2[float],
  render: () -> Element
): Context {.exportc.} =
  echo "Testing init"
  text.measureText = measureTextFunction
  windowSize = behaviorSubject(size)
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
    dispatchUpdate: proc(dt: float): void =
      dispatchUpdate(dt)
      discard rootElement.dispatchUpdate(dt),
    scale: scale,
    size: size,
  )

proc nim_interop_test() {.exportc.}=
  echo "Hello, world. From nim."
