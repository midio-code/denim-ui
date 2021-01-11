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

createElementEvent(pointerEntered, PointerArgs, void)
createElementEvent(pointerExited, PointerArgs, void)
createElementEvent(pointerMoved, PointerArgs, EventResult)
createElementEvent(pointerClicked, PointerArgs, EventResult)
createElementEvent(pointerPressed, PointerArgs, EventResult)
createElementEvent(pointerReleased, PointerArgs, EventResult)

var pointerCapturedEmitter* = emitter[Element]()
var pointerCaptureReleasedEmitter* = emitter[Element]()
var keyDownEmitter* = emitter[KeyArgs]()
var keyUpEmitter* = emitter[KeyArgs]()

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
  PointerArgs(sender: element, actualPos: pos, viewportPos: pos, pointerIndex: pointerIndex)

proc pointerArgs*(element: Element, x, y: float, pointerIndex: PointerIndex): PointerArgs =
  PointerArgs(sender: element, actualPos: vec2(x,y), viewportPos: vec2(x,y), pointerIndex: pointerIndex)

proc withElem(self: PointerArgs, elem: Element): PointerArgs =
  PointerArgs(sender: elem, actualPos: self.actualPos, viewportPos: self.viewportPos, pointerIndex: self.pointerIndex)


var elementsHandledPointerDownThisUpdate = initHashSet[Element]()
proc dispatchPointerDownImpl*(self: Element, arg: PointerArgs): EventResult =
  if self.props.visibility == Visibility.Collapsed:
    return

  let transformedArg = arg.transformed(self)
  if not self.isPointInside(transformedArg.actualPos):
    return

  for child in self.childrenSortedByZIndex.reverse():
    let result = child.dispatchPointerDownImpl(transformedArg)
    if result.handled:
       return result
  if self.isPointInside(transformedArg.actualPos):
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
  if not self.isPointInside(transformedArg.actualPos) and not self.hasPointerCapture:
    return

  for child in self.childrenSortedByZIndex.reverse():
    let result = child.dispatchPointerUpImpl(transformedArg)
    if result.handled:
      return result
  if (self.isPointInside(transformedArg.actualPos) or self.pointerCaptured()):
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
  for child in self.childrenSortedByZIndex:
    if child.pointerInsideLastUpdate:
      let transformedArg = arg.transformed(child).withElem(child)
      child.pointerExited(transformedArg)


var elementsHandledPointerMoveThisUpdate = initHashSet[Element]()
proc dispatchPointerMoveImpl(self: Element, arg: PointerArgs): EventResult =
  if self.props.visibility == Visibility.Collapsed:
    return

  let transformedArg = arg.transformed(self)
  let pointInside = self.isPointInside(transformedArg.actualPos)

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
    for child in self.childrenSortedByZIndex.reverse():
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

proc transformArgFromRootElem(self: Element, arg: PointerArgs): PointerArgs =
  var a = arg
  if self.parent.isSome():
    a = self.parent.get().transformArgFromRootElem(arg)
  a.transformed(self)

proc dispatchPointerMove*(self: Element, arg: PointerArgs): EventResult =
  elementsHandledPointerMoveThisUpdate.clear()
  result = self.dispatchPointerMoveImpl(arg)
  if pointerCapturedTo.isSome():
    let capturedElem = pointerCapturedTo.get()
    if not elementsHandledPointerMoveThisUpdate.contains(capturedElem):
      var transformedArg = capturedElem.transformArgFromRootElem(arg)
      discard capturedElem.dispatchPointerMoveImpl(transformedArg)

createElementEvent(wheel, WheelArgs, EventResult)

proc dispatchWheel*(self: Element, args: WheelArgs): EventResult =
  if self.props.visibility == Visibility.Collapsed:
    return
  let transformedArg = args.transformed(self)
  if not self.isPointInside(transformedArg.actualPos):
    return
  for child in self.childrenSortedByZIndex.reverse():
    let res = child.dispatchWheel(transformedArg)
    if res.handled:
      return res
  for handler in self.wheelHandlers:
    let res = handler(transformedArg)
    if res.handled:
      return res


proc observePointerPos*(self: Element): Observable[PointerArgs] =
  let ret = subject[PointerArgs]()
  self.onPointerMoved(
    proc(arg: PointerArgs): EventResult =
      ret <- arg
  )
  ret.source
