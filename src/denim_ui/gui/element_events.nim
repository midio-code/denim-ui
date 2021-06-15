import sugar, tables, options, sets, strformat
import types
import element
import rx_nim
import focus_manager
import key_bindings
import types
import pointer_capture
import ../events
import ../guid
import ../utils
import ../vec
import ../transform

type
  EventResult* = object
    handledBy: seq[Guid]

proc `$`(self: EventResult): string =
  &"EventResult({self.handledBy})"

proc `&`(self: EventResult, other: EventResult): EventResult =
  EventResult(
    handledBy: self.handledBy & other.handledBy
  )

proc addHandledBy*(self: var EventResult, id: Guid): void =
  self.handledBy.add(id)

template addHandledBy*(self: var EventResult, id: Guid, label: string): void =
  when defined(debug_pointer_events):
    echo "Adding handled by: ", id, " - ", label
  self.addHandledBy(id)

proc isHandledBy*(self: EventResult, id: Guid): bool =
  id in self.handledBy

proc isHandled*(self: EventResult): bool =
  self.handledBy.len > 0

proc isHandledByOtherThan*(self: EventResult, id: Guid): bool =
  self.isHandled and not self.isHandledBy(id)

proc transformed(args: PointerArgs, elem: Element): PointerArgs =
  PointerArgs(
    sender: args.sender,
    pointerIndex: args.pointerIndex,
    actualPos: args.actualPos.transformOnlyBy(elem),
    viewportPos: args.viewportPos
  )

proc transformed(args: WheelArgs, elem: Element): WheelArgs =
  WheelArgs(
    deltaX: args.deltaX,
    deltaY: args.deltaY,
    deltaZ: args.deltaZ,
    unit: args.unit,
    actualPos: args.actualPos.transformOnlyBy(elem),
    viewportPos: args.viewportPos
  )

template createElementEvent(name: untyped, argsType: typedesc): untyped =
  var eventTable = initTable[Element, seq[(argsType, var EventResult) -> void]]()
  proc `on name`*(self: Element, handler: (argsType, var EventResult) -> void): void =
    if not eventTable.hasKey(self):
      let arr: seq[(argsType, var EventResult) -> void] = @[]
      eventTable[self] = arr
    eventTable[self].add(handler)
  proc `name handlers`(self: Element): seq[(argsType, var EventResult) -> void] =
    if eventTable.hasKey(self):
      eventTable[self]
    else:
      @[]

createElementEvent(pointerEntered, PointerArgs)
createElementEvent(pointerExited, PointerArgs)
createElementEvent(pointerMoved, PointerArgs)
createElementEvent(pointerPressed, PointerArgs)
createElementEvent(pointerReleased, PointerArgs)

createElementEvent(wheel, WheelArgs)

createEvent(pointerMovedGlobal, PointerArgs)
createEvent(pointerPressedGlobal, PointerArgs)
createEvent(pointerReleasedGlobal, PointerArgs)

createEvent(keyDownGlobal, KeyArgs)
createEvent(keyUpGlobal, KeyArgs)

createElementEvent(keyDown, KeyArgs)
createElementEvent(keyUp, KeyArgs)

proc dispatchKeyDown*(args: KeyArgs): EventResult =
  emitKeyDownGlobal(args)
  dispatchGlobalKeyBindings(args)

  let focusedElem = getCurrentlyFocusedElement()
  if focusedElem.isSome:
    result = EventResult(handledBy: @[])
    for handler in focusedElem.get.keyDownHandlers:
      handler(args, result)
    focusedElem.get.dispatchKeyBindings(args)

proc dispatchKeyUp*(args: KeyArgs): EventResult =
  emitKeyUpGlobal(args)
  let focusedElem = getCurrentlyFocusedElement()
  if focusedElem.isSome:
    result = EventResult(handledBy: @[])
    for handler in focusedElem.get.keyUpHandlers:
      handler(args, result)

proc pointerArgs*(element: Element, pos: Vec2[float], pointerIndex: PointerIndex): PointerArgs =
  PointerArgs(sender: element, actualPos: pos, viewportPos: pos, pointerIndex: pointerIndex)

proc pointerArgs*(element: Element, x, y: float, pointerIndex: PointerIndex): PointerArgs =
  PointerArgs(sender: element, actualPos: vec2(x,y), viewportPos: vec2(x,y), pointerIndex: pointerIndex)

proc withElem(self: PointerArgs, elem: Element): PointerArgs =
  PointerArgs(sender: elem, actualPos: self.actualPos, viewportPos: self.viewportPos, pointerIndex: self.pointerIndex)


var elementsHandledPointerDownThisUpdate = initHashSet[Element]()
proc dispatchPointerDownImpl*(self: Element, arg: PointerArgs, res: var EventResult): void =
  if self.props.visibility == Visibility.Collapsed:
    return

  let transformedArg = arg.transformed(self)
  if not self.isPointInside(transformedArg.actualPos):
    return

  for child in self.childrenSortedByZIndexReverse:
    child.dispatchPointerDownImpl(transformedArg, res)

  if self.isPointInside(transformedArg.actualPos):
    elementsHandledPointerDownThisUpdate.incl(self)
    for handler in self.pointerPressedHandlers:
      handler(transformedArg.withElem(self), res)

var elementsHandledPointerUpThisUpdate = initHashSet[Element]()
proc dispatchPointerUpImpl*(self: Element, arg: PointerArgs, res: var EventResult): void =
  if self.props.visibility == Visibility.Collapsed:
    return

  let transformedArg = arg.transformed(self)
  if not self.isPointInside(transformedArg.actualPos) and not self.hasPointerCapture:
    return

  for child in self.childrenSortedByZIndexReverse:
    child.dispatchPointerUpImpl(transformedArg, res)

  if (self.isPointInside(transformedArg.actualPos) or self.hasPointerCapture()):
    elementsHandledPointerUpThisUpdate.incl(self)
    for handler in self.pointerReleasedHandlers:
      handler(transformedArg.withElem(self), res)

proc pointerEntered(self: Element, arg: PointerArgs, res: var EventResult): void =
  self.pointerInsideLastUpdate = true
  for handler in self.pointerEnteredHandlers:
    handler(arg.withElem(self), res)

proc pointerExited(self: Element, arg: PointerArgs, res: var EventResult): void =
  self.pointerInsideLastUpdate = false
  for handler in self.pointerExitedHandlers:
    handler(arg.withElem(self), res)
  for child in self.childrenSortedByZIndex:
    if child.pointerInsideLastUpdate:
      let transformedArg = arg.transformed(child).withElem(child)
      child.pointerExited(transformedArg, res)


var elementsHandledPointerMoveThisUpdate = initHashSet[Element]()
proc dispatchPointerMoveImpl(
  self: Element,
  arg: PointerArgs,
  res: var EventResult,
  enterRes: var EventResult,
  exitRes: var EventResult,
): void =
  if self.props.visibility == Visibility.Collapsed:
    return

  let transformedArg = arg.transformed(self)
  let pointInside = self.isPointInside(transformedArg.actualPos)

  if pointInside or self.hasPointerCapture:
    if self.pointerInsideLastUpdate == false:
      self.pointerEntered(transformedArg, enterRes)
    for child in self.childrenSortedByZIndexReverse:
      child.dispatchPointerMoveImpl(transformedArg, res, enterRes, exitRes)
    elementsHandledPointerMoveThisUpdate.incl(self)
    for handler in self.pointerMovedHandlers:
      handler(transformedArg.withElem(self), res)
  elif self.pointerInsideLastUpdate:
    self.pointerExited(transformedArg, exitRes)

proc dispatchPointerDown*(self: Element, arg: PointerArgs): EventResult =
  elementsHandledPointerDownThisUpdate.clear()

  result = EventResult(handledBy: @[])

  emitPointerPressedGlobal(arg)
  self.dispatchPointerDownImpl(arg, result)

  # TODO: Only captured elements should get the event
  if pointerIsCaptured():
    for captor in pointerCaptors():
      if not elementsHandledPointerDownThisUpdate.contains(captor):
        captor.dispatchPointerDownImpl(arg, result)

proc dispatchPointerUp*(self: Element, arg: PointerArgs): EventResult =
  elementsHandledPointerUpThisUpdate.clear()

  result = EventResult(handledBy: @[])

  emitPointerReleasedGlobal(arg)
  self.dispatchPointerupImpl(arg, result)

  # TODO: Only captured elements should get the event
  if pointerIsCaptured():
    for captor in pointerCaptors():
      if not elementsHandledPointerUpThisUpdate.contains(captor):
        captor.dispatchPointerUpImpl(arg, result)

proc transformArgFromRootElem(self: Element, arg: PointerArgs): PointerArgs =
  var a = arg
  if self.parent.isSome():
    a = self.parent.get().transformArgFromRootElem(arg)
  a.transformed(self)

var lastPointerPos: Option[Point]

proc getCurrentPointerPos*(): Option[Point] =
  lastPointerPos

proc dispatchPointerMove*(self: Element, arg: PointerArgs): EventResult =
  lastPointerPos = some(arg.actualPos)
  elementsHandledPointerMoveThisUpdate.clear()
  emitPointerMovedGlobal(arg)

  result = EventResult(handledBy: @[])
  var enterResult = EventResult(handledBy: @[])
  var exitResult = EventResult(handledBy: @[])

  if pointerIsCaptured():
    for captor in pointerCaptors():
      if not elementsHandledPointerMoveThisUpdate.contains(captor):
        var transformedArg = captor.transformArgFromRootElem(arg)
        captor.dispatchPointerMoveImpl(transformedArg, result, enterResult, exitResult)
  else:
    self.dispatchPointerMoveImpl(arg, result, enterResult, exitResult)

proc dispatchWheelImpl*(self: Element, args: WheelArgs, res: var EventResult): void =
  let transformedArg = args.transformed(self)
  if not self.isPointInside(transformedArg.actualPos) and not self.hasPointerCapture:
    return

  for child in self.childrenSortedByZIndexReverse:
    child.dispatchWheelImpl(transformedArg, res)
  for handler in self.wheelHandlers:
    handler(transformedArg, res)

proc dispatchWheel*(self: Element, args: WheelArgs): EventResult =
  if self.props.visibility == Visibility.Collapsed:
    return

  result = EventResult(handledBy: @[])
  self.dispatchWheelImpl(args, result)


proc observePointerPos*(self: Element): Observable[PointerArgs] =
  let ret = subject[PointerArgs]()
  self.onPointerMoved(
    proc(arg: PointerArgs, res: var EventResult): void =
      ret <- arg
  )
  ret.source
