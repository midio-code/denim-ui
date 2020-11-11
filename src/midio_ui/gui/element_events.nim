import sugar, tables, options, sets, strformat
import types
import element
import rx_nim
import ../events
import ../utils
import ../vec
import ../transform

type
  EventResult* = object
    handled: bool
proc handled*(): EventResult =
  EventResult(handled: true)
proc unhandled*(): EventResult =
  EventResult(handled: false)


template createElementEvent*(name: untyped, T: typedesc, TRes: typedesc): untyped =
  var eventTable = initTable[Element, seq[T -> TRes]]()
  proc `on name`*(self: Element, handler: T -> TRes): void =
    if not eventTable.hasKey(self):
      let arr: seq[T -> TRes] = @[]
      eventTable[self] = arr
    eventTable[self].add(handler)
  proc `name handlers`(self: Element): seq[T -> TRes] =
    if eventTable.hasKey(self):
      eventTable[self]
    else:
      @[]

type
  KeyArgs* = ref object
    key*: string
    keyCode*: int

  PointerArgs* = ref object
    # TODO: Remove sender from pointer args?
    sender*: Element
    pos*: Vec2[float]
    pointerIndex*: PointerIndex

  WheelDeltaUnit* = enum
    Pixel, Line, Page

  WheelArgs* = object
    pos*: Vec2[float]
    deltaX*: float
    deltaY*: float
    deltaZ*: float
    unit*: WheelDeltaUnit

proc transformed(args: PointerArgs, elem: Element): PointerArgs =
  PointerArgs(
    sender: args.sender,
    pointerIndex: args.pointerIndex,
    pos: args.pos.transform(elem)
  )

proc transformed(args: WheelArgs, elem: Element): WheelArgs =
  WheelArgs(
    deltaX: args.deltaX,
    deltaY: args.deltaY,
    deltaZ: args.deltaZ,
    unit: args.unit,
    pos: args.pos.transform(elem)
  )

createElementEvent(pointerEntered, PointerArgs, void)
createElementEvent(pointerExited, PointerArgs, void)
createElementEvent(pointerMoved, PointerArgs, EventResult)
createElementEvent(pointerClicked, PointerArgs, EventResult)
createElementEvent(pointerPressed, PointerArgs, EventResult)
createElementEvent(pointerReleased, PointerArgs, EventResult)

var pointerCapturedEmitter* = emitter[Element]()
var pointerCaptureReleasedEmitter* = emitter[Element]()
var keyDownEmitter* = emitter[KeyArgs]()

var pointerCapturedTo = none[Element]()

proc pointerCaptured*(self: Element): bool =
  pointerCapturedTo.isSome() and pointerCapturedTo.get() == self

proc releasePointer*(self: Element) =
  if pointerCapturedTo == self:
    pointerCapturedTo = none[Element]()
    pointerCaptureReleasedEmitter.emit(self)

proc hasPointerCapture*(self: Element): bool =
  pointerCapturedTo.map(x => x == self).get(false)

proc pointerCapturedBySomeoneElse*(self: Element): bool =
  pointerCapturedTo.isSome() and pointerCapturedTo.get() != self

proc capturePointer*(self: Element): void =
  if pointerCapturedBySomeoneElse(self):
    echo "WARN: Tried to capture pointer that was already captured by someone else!"

  pointerCapturedTo = some(self)
  pointerCapturedEmitter.emit(self)

proc pointerArgs*(element: Element, pos: Vec2[float], pointerIndex: PointerIndex): PointerArgs =
  PointerArgs(sender: element, pos: pos, pointerIndex: pointerIndex)

proc pointerArgs*(element: Element, x, y: float, pointerIndex: PointerIndex): PointerArgs =
  PointerArgs(sender: element, pos: vec2(x,y), pointerIndex: pointerIndex)

proc withElem(self: PointerArgs, elem: Element): PointerArgs =
  PointerArgs(sender: elem, pos: self.pos, pointerIndex: self.pointerIndex)


var elementsHandledPointerDownThisUpdate = initHashSet[Element]()
proc dispatchPointerDownImpl*(self: Element, arg: PointerArgs): EventResult =
  if self.props.visibility == Visibility.Collapsed:
    return

  let transformedArg = arg.transformed(self)
  if not self.isPointInside(transformedArg.pos):
    return

  for child in self.children.reverse():
    let result = child.dispatchPointerDownImpl(transformedArg)
    if result.handled:
       return result
  if self.isPointInside(transformedArg.pos):
    elementsHandledPointerDownThisUpdate.incl(self)
    for handler in self.pointerPressedHandlers:
      let res = handler(transformedArg.withElem(self))
      if res.handled:
        return res

var elementsHandledPointerUpThisUpdate = initHashSet[Element]()
proc dispatchPointerUpImpl*(self: Element, arg: PointerArgs): EventResult =
  if self.props.visibility == Visibility.Collapsed:
    return

  let transformedArg = arg.transformed(self)
  if not self.isPointInside(transformedArg.pos) and not self.hasPointerCapture:
    return

  for child in self.children.reverse():
    let result = child.dispatchPointerUpImpl(transformedArg)
    if result.handled:
      return result
  if (self.isPointInside(transformedArg.pos) or self.pointerCaptured()):
    elementsHandledPointerUpThisUpdate.incl(self)
    for handler in self.pointerReleasedHandlers:
      let res = handler(transformedArg.withElem(self))
      if res.handled:
        return res


proc pointerEntered(self: Element, arg: PointerArgs): void =
  self.pointerInsideLastUpdate = true
  for handler in self.pointerEnteredHandlers:
    handler(arg.withElem(self))

proc pointerExited(self: Element, arg: PointerArgs): void =
  self.pointerInsideLastUpdate = false
  for handler in self.pointerExitedHandlers:
    handler(arg.withElem(self))
  for child in self.children:
    if child.pointerInsideLastUpdate:
      let transformedArg = arg.transformed(child).withElem(child)
      child.pointerExited(transformedArg)


var elementsHandledPointerMoveThisUpdate = initHashSet[Element]()
proc dispatchPointerMoveImpl(self: Element, arg: PointerArgs): EventResult =
  if self.props.visibility == Visibility.Collapsed:
    return

  let transformedArg = arg.transformed(self)
  let pointInside = self.isPointInside(transformedArg.pos)

  # let defaultName = self.props.debugName.get("noName")
  # echo &"Is point inside: {defaultName}? {transformedArg.pos} - {pointInside}"

  if pointInside or self.hasPointerCapture:
    if self.pointerInsideLastUpdate == false:
      self.pointerEntered(transformedArg)
    elementsHandledPointerMoveThisUpdate.incl(self)
    for handler in self.pointerMovedHandlers:
      let res = handler(transformedArg.withElem(self))
      if res.handled:
        return res
    for child in self.children.reverse():
      result = child.dispatchPointerMoveImpl(transformedArg)
      if result.handled:
        return result
  elif self.pointerInsideLastUpdate:
    self.pointerExited(transformedArg)
    return

proc dispatchPointerDown*(self: Element, arg: PointerArgs): EventResult =
  elementsHandledPointerDownThisUpdate.clear()
  self.dispatchPointerDownImpl(arg)

proc dispatchPointerUp*(self: Element, arg: PointerArgs): EventResult =
  elementsHandledPointerUpThisUpdate.clear()
  result = self.dispatchPointerUpImpl(arg)
  if pointerCapturedTo.isSome():
    let capturedElem = pointerCapturedTo.get()
    if not elementsHandledPointerUpThisUpdate.contains(capturedElem):
      discard capturedElem.dispatchPointerUpImpl(arg)


proc dispatchPointerMove*(self: Element, arg: PointerArgs): EventResult =
  elementsHandledPointerMoveThisUpdate.clear()
  result = self.dispatchPointerMoveImpl(arg)
  if pointerCapturedTo.isSome():
    let capturedElem = pointerCapturedTo.get()
    if not elementsHandledPointerMoveThisUpdate.contains(capturedElem):
      discard capturedElem.dispatchPointerMoveImpl(arg)

createElementEvent(wheel, WheelArgs, EventResult)

proc dispatchWheel*(self: Element, args: WheelArgs): EventResult =
  if self.props.visibility == Visibility.Collapsed:
    return
  let transformedArg = args.transformed(self)
  if not self.isPointInside(transformedArg.pos):
    return
  for child in self.children.reverse():
    let res = child.dispatchWheel(transformedArg)
    if res.handled:
      return res
  for handler in self.wheelHandlers:
    let res = handler(transformedArg)
    if res.handled:
      return res
