import sugar, tables, options, sets, strformat
import types
import element
import rx_nim
import ../events
import ../guid
import ../utils
import ../vec
import ../transform

type

  PointerCaptureChangedArgs* = object

  EventResult* = object
    handledBy: seq[Guid]

proc `&`(self: EventResult, other: EventResult): EventResult =
  EventResult(
    handledBy: self.handledBy & other.handledBy
  )

proc addHandledBy*(self: var EventResult, id: Guid): void =
  self.handledBy.add(id)

proc isHandledBy*(self: EventResult, id: Guid): bool =
  id in self.handledBy

type
  KeyArgs* = ref object
    key*: string
    keyCode*: int

  PointerArgs* = ref object
    # TODO: Remove sender from pointer args?
    sender*: Element
    ## The original position of the pointer in the viewport
    viewportPos*: Point
    ## The actual position of the pointer transformed to the context of the currently visited element
    actualPos*: Point # TODO: Might move this somewhere else as it is only meaningful in the context of "visiting an element" (as we do in out pointer events for example)
    pointerIndex*: PointerIndex

  WheelDeltaUnit* = enum
    Pixel, Line, Page

  WheelArgs* = object
    actualPos*: Point
    viewportPos*: Point
    deltaX*: float
    deltaY*: float
    deltaZ*: float
    unit*: WheelDeltaUnit

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

var pointerCapturedEmitter* = emitter[PointerCaptureChangedArgs]()
var pointerCaptureReleasedEmitter* = emitter[PointerCaptureChangedArgs]()
var keyDownEmitter* = emitter[KeyArgs]()
var keyUpEmitter* = emitter[KeyArgs]()

type
  PointerCapture = tuple[owner: Element, lostCapture: Option[() -> void]]

var pointerCapturedTo = none[PointerCapture]()

proc pointerCaptured*(self: Element): bool =
  pointerCapturedTo.isSome() and pointerCapturedTo.get.owner == self

proc releasePointer*(self: Element) =
  if pointerCapturedTo.isSome and pointerCapturedTo.get.owner == self:
    let lostCaptureCallback = pointerCapturedTo.get.lostCapture
    pointerCapturedTo = none[PointerCapture]()
    pointerCaptureReleasedEmitter.emit(PointerCaptureChangedArgs())
    if lostCaptureCallback.isSome:
      lostCaptureCallback.get()()

proc hasPointerCapture*(self: Element): bool =
  pointerCapturedTo.map(x => x.owner == self).get(false)

proc pointerCapturedBySomeoneElse*(self: Element): bool =
  pointerCapturedTo.isSome and pointerCapturedTo.get.owner != self

proc capturePointer*(self: Element, lostCapture: Option[() -> void] = none[() -> void]()): void =
  if pointerCapturedBySomeoneElse(self):
    echo "WARN: Tried to capture pointer that was already captured by someone else!"

  pointerCapturedTo = some((self, lostCapture))
  pointerCapturedEmitter.emit(PointerCaptureChangedArgs())

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

  for child in self.childrenSortedByZIndex.reverse:
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

  for child in self.childrenSortedByZIndex.reverse:
    child.dispatchPointerUpImpl(transformedArg, res)

  if (self.isPointInside(transformedArg.actualPos) or self.pointerCaptured()):
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
proc dispatchPointerMoveImpl(self: Element, arg: PointerArgs, res: var EventResult): void =
  if self.props.visibility == Visibility.Collapsed:
    return

  let transformedArg = arg.transformed(self)
  let pointInside = self.isPointInside(transformedArg.actualPos)

  if pointInside or self.hasPointerCapture:
    if self.pointerInsideLastUpdate == false:
      self.pointerEntered(transformedArg, res)
    for child in self.childrenSortedByZIndex.reverse:
      child.dispatchPointerMoveImpl(transformedArg, res)
    elementsHandledPointerMoveThisUpdate.incl(self)
    for handler in self.pointerMovedHandlers:
      handler(transformedArg.withElem(self), res)
  elif self.pointerInsideLastUpdate:
    self.pointerExited(transformedArg, res)

proc dispatchPointerDown*(self: Element, arg: PointerArgs): EventResult =
  elementsHandledPointerDownThisUpdate.clear()

  result = EventResult(handledBy: @[])

  self.dispatchPointerDownImpl(arg, result)

  # NOTE: If anyone has capture, only they get the event
  if pointerCapturedTo.isSome():
    let capturedElem = pointerCapturedTo.get.owner
    if not elementsHandledPointerDownThisUpdate.contains(capturedElem):
      capturedElem.dispatchPointerDownImpl(arg, result)
  else:
    emitPointerPressedGlobal(arg)

proc dispatchPointerUp*(self: Element, arg: PointerArgs): EventResult =
  elementsHandledPointerUpThisUpdate.clear()
  emitPointerReleasedGlobal(arg)

  result = EventResult(handledBy: @[])

  # NOTE: If anyone has capture, only they get the event
  if pointerCapturedTo.isSome():
    let capturedElem = pointerCapturedTo.get.owner
    if not elementsHandledPointerUpThisUpdate.contains(capturedElem):
      capturedElem.dispatchPointerUpImpl(arg, result)
  else:
    self.dispatchPointerUpImpl(arg, result)

proc transformArgFromRootElem(self: Element, arg: PointerArgs): PointerArgs =
  var a = arg
  if self.parent.isSome():
    a = self.parent.get().transformArgFromRootElem(arg)
  a.transformed(self)

proc dispatchPointerMove*(self: Element, arg: PointerArgs): EventResult =
  elementsHandledPointerMoveThisUpdate.clear()
  emitPointerMovedGlobal(arg)

  result = EventResult(handledBy: @[])

  if pointerCapturedTo.isSome:
    let capturedElem = pointerCapturedTo.get.owner
    if not elementsHandledPointerMoveThisUpdate.contains(capturedElem):
      var transformedArg = capturedElem.transformArgFromRootElem(arg)
      capturedElem.dispatchPointerMoveImpl(transformedArg, result)
  else:
    self.dispatchPointerMoveImpl(arg, result)

proc dispatchWheelImpl*(self: Element, args: WheelArgs, res: var EventResult): void =
  let transformedArg = args.transformed(self)
  if not self.isPointInside(transformedArg.actualPos):
    return

  for child in self.childrenSortedByZIndex:
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
