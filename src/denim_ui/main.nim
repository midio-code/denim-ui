import sugar, options, strformat
import gui/prelude
import gui/primitives/text
import gui/primitives/path
import gui/native_element
import gui/update_manager
import monotimes_fork
import gui/element_bounds_changed_event

type
  Context* = ref object
    render*: (Context, float) -> Option[Primitive]
    requestRerender*: () -> void
    dispatchPointerMove*: (x: float, y: float) -> void
    dispatchPointerDown*: (x: float, y: float, pointerIndex: PointerIndex) -> void
    dispatchPointerUp*: (x: float, y: float, pointerIndex: PointerIndex) -> void
    dispatchWheel*: (x: float, y: float, deltaX: float, deltaY: float, deltaZ: float, unit: WheelDeltaUnit) -> void
    dispatchKeyDown*: (key: string, modifiers: seq[string]) -> void
    dispatchKeyUp*: (key: string, modifiers: seq[string]) -> void
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
var lastPointerIndex: PointerIndex

var pointerPressedLastFrame = false
var pointerPressedThisFrame = false


type
  KeyEventKind {.pure.} = enum
    Down, Up
  KeyEvent = ref object
    kind: KeyEventKind
    args: KeyArgs

var keyEventsThisFrame: seq[KeyEvent] = @[]


var wheelEventsLastFrame: seq[WheelArgs] = @[]

var windowSize: Vec2[float]

proc scaleMousePos(ctx: Context, pos: Vec2[float]): Vec2[float] =
  vec2(pos.x / ctx.scale.x, pos.y / ctx.scale.y)

var samples = 0
var startTime = float(getMonoTime().ticks) / 1000000.0

proc update*(ctx: Context, dt: float): void {.exportc.} =
  let availableRect = rect(zero(), windowSize.divide(ctx.scale))
  performOutstandingLayoutsAndMeasures(availableRect)
  emitBoundsChangedEventsFromPreviousFrame()

  # NOTE: This must be called before each frame
  recalculateWorldPositionsCache(ctx.rootElement)

  update_manager.dispatchNextFrameActions()

  if pointerPosChangedThisFrame:
    # TODO: Handle the case where multiple events happen per frame (as we do for wheelEvents)
    discard ctx.rootElement.dispatchPointerMove(pointerArgs(ctx.rootElement, ctx.scaleMousePos(lastPointerPos), lastPointerIndex))
    pointerPosChangedThisFrame = false

  if pointerPressedLastFrame == false and pointerPressedThisFrame == true:
    # TODO: Handle the case where multiple events happen per frame (as we do for wheelEvents)
    discard ctx.rootElement.dispatchPointerDown(pointerArgs(ctx.rootElement, ctx.scaleMousePos(lastPointerPos), lastPointerIndex))
    pointerPressedLastFrame = true

  if pointerPressedLastFrame == true and pointerPressedThisFrame == false:
    # TODO: Handle the case where multiple events happen per frame (as we do for wheelEvents)
    discard ctx.rootElement.dispatchPointerUp(pointerArgs(ctx.rootElement, ctx.scaleMousePos(lastPointerPos), lastPointerIndex))
    pointerPressedLastFrame = false

  let keyEvents = keyEventsThisFrame
  keyEventsThisFrame = @[]
  for event in keyEvents:
    case event.kind:
      of KeyEventKind.Down:
        discard dispatchKeyDown(event.args)
      of KeyEventKind.Up:
        discard dispatchKeyUp(event.args)

  if wheelEventsLastFrame.len > 0:
    for arg in wheelEventsLastFrame:
      # TODO: Clean up
      var a = arg
      a.actualPos = a.actualPos / ctx.scale
      discard ctx.rootElement.dispatchWheel(a)
    wheelEventsLastFrame = @[]

  update_manager.dispatchUpdate(dt)
  performOutstandingLayoutsAndMeasures(availableRect)
  dispatchBeforeRenderEvent()
  if not ctx.rootElement.isVisualValid:
    ctx.requestRerender()

proc render*(ctx: Context): Option[Primitive] {.exportc.} =
  result = ctx.rootElement.dispatchRender()
  if result.isSome:
    result.get().children = result.get().children

proc dispatchWindowSizeChanged*(newSize: Vec2[float]): void {.exportc.} =
  windowSize = newSize

proc dispatchPointerMove*(x: float, y: float): void {.exportc.} =
  if (lastPointerPos.x != x or lastPointerPos.y != y) and pointerPosChangedThisFrame == false:
    pointerPosChangedThisFrame = true
    lastPointerPos = vec2(x, y)

proc dispatchPointerPress*(x: float, y: float, pointerIndex: PointerIndex): void {.exportc.} =
  lastPointerPos = vec2(x, y)
  lastPointerIndex = pointerIndex
  pointerPressedThisFrame = true

proc dispatchPointerRelease*(x: float, y: float, pointerIndex: PointerIndex): void {.exportc.} =
  lastPointerPos = vec2(x, y)
  lastPointerIndex = pointerIndex
  # TODO: This does not work if both press and release happens on the same frame
  pointerPressedThisFrame = false

proc dispatchWheel*(x: float, y: float, deltaX: float, deltaY: float, deltaZ: float, unit: WheelDeltaUnit): void {.exportc.} =
  wheelEventsLastFrame.add(WheelArgs(
    actualPos: vec2(x, y),
    viewportPos: vec2(x, y),
    deltaX: deltaX,
    deltaY: deltaY,
    deltaZ: deltaZ,
    unit: unit
  ))

proc dispatchKeyDown*(key: string, modifiers: seq[string]): void {.exportc.} =
  keyEventsThisFrame.add(
    KeyEvent(
      kind: KeyEventKind.Down,
      args: KeyArgs(
        key: key, # TODO: We seem to be gettin the wrong key
        modifiers: modifiers
      )
    )
  )

proc dispatchKeyUp*(key: string, modifiers: seq[string]): void {.exportc.} =
  keyEventsThisFrame.add(
    KeyEvent(
      kind: KeyEventKind.Up,
      args: KeyArgs(
        key: key, # TODO: We seem to be gettin the wrong key
        modifiers: modifiers
      )
    )
  )

proc init*(
  size: Vec2[float],
  scale: Vec2[float],
  measureTextFunction: (string, float, string, int, Baseline) -> Vec2[float],
  hitTestPath: (Element, PathProps, Point) -> bool,
  requestRerender: () -> void,
  render: () -> Element,
  nativeElements: NativeElements,
  setCursorHandler: (Cursor) -> void
): Context =
  setCursor = setCursorHandler
  text.measureText = measureTextFunction
  path.hitTestPath = hitTestPath
  nativeElementsSingleton = nativeElements
  windowSize = size
  let rootElement =
    render()

  rootElement.addTag("root")
  rootElement.setParentOnChildren()
  rootElement.dispatchOnRooted()
  rootElement.invalidateLayout()
  result = Context(
    rootElement: rootElement,
    requestRerender: requestRerender,
    dispatchPointerMove: dispatchPointerMove,
    dispatchPointerDown: dispatchPointerPress,
    dispatchPointerUp: dispatchPointerRelease,
    dispatchWheel: dispatchWheel,
    dispatchKeyDown: dispatchKeyDown,
    dispatchKeyUp: dispatchKeyUp,
    dispatchWindowSizeChanged: dispatchWindowSizeChanged,
    scale: scale,
    size: size,
  )
