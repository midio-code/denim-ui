import sugar, tables, options, sets
import types
import element
import ../observables/observables
import ../events
import ../utils
import ../vec

type
  PointerEventResult* = object
    handled: bool
proc handled*(): PointerEventResult =
  PointerEventResult(handled: true)
proc unhandled*(): PointerEventResult =
  PointerEventResult(handled: false)


template createElementEvent*(name: untyped, T: typedesc): untyped =
  var eventTable = initTable[Element, seq[T -> PointerEventResult]]()
  proc `on name`*(self: Element, handler: T -> PointerEventResult): void =
    if not eventTable.hasKey(self):
      let arr: seq[T -> PointerEventResult] = @[]
      eventTable[self] = arr
    eventTable[self].add(handler)
  proc `name handlers`(self: Element): seq[T -> PointerEventResult] =
    if eventTable.hasKey(self):
      eventTable[self]
    else:
      @[]

type
  KeyArgs* = ref object
    key*: string
    keyCode*: int

  PointerArgs* = ref object
    sender*: Element
    pos*: Vec2[float]

template createPointerEvent(name: untyped): untyped =
  createElementEvent(name, PointerArgs)

createPointerEvent(pointerEntered)
createPointerEvent(pointerExited)
createPointerEvent(pointerMoved)
createPointerEvent(pointerClicked)
createPointerEvent(pointerPressed)
createPointerEvent(pointerReleased)
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

proc pointerArgs*(element: Element, pos: Vec2[float]): PointerArgs =
  PointerArgs(sender: element, pos: pos)

proc pointerArgs*(element: Element, x, y: float): PointerArgs =
  PointerArgs(sender: element, pos: vec2(x,y))

proc withElem(self: PointerArgs, elem: Element): PointerArgs =
  PointerArgs(sender: elem, pos: self.pos)


var elementsHandledPointerDownThisUpdate = initHashSet[Element]()
proc dispatchPointerDownImpl*(self: Element, arg: PointerArgs): PointerEventResult =
  if self.props.visibility == Visibility.Collapsed:
    return
  for child in self.children.reverse():
    let result = child.dispatchPointerDownImpl(arg)
    if result.handled:
       return result
  if self.isPointInside(arg.pos):
    elementsHandledPointerDownThisUpdate.incl(self)
    for handler in self.pointerPressedHandlers:
      let res = handler(arg.withElem(self))
      if res.handled:
        return res

var elementsHandledPointerUpThisUpdate = initHashSet[Element]()
proc dispatchPointerUpImpl*(self: Element, arg: PointerArgs): PointerEventResult =
  if self.props.visibility == Visibility.Collapsed:
    return

  for child in self.children.reverse():
    let result = child.dispatchPointerUpImpl(arg)
    if result.handled:
      return result
  if (self.isPointInside(arg.pos) or self.pointerCaptured()):
    elementsHandledPointerUpThisUpdate.incl(self)
    for handler in self.pointerReleasedHandlers:
      let res = handler(arg.withElem(self))
      if res.handled:
        return res

var elementsHandledPointerMoveThisUpdate = initHashSet[Element]()
proc dispatchPointerMoveImpl(self: Element, arg: PointerArgs): PointerEventResult =
  if self.props.visibility == Visibility.Collapsed:
    return
  for child in self.children.reverse():
    result = child.dispatchPointerMoveImpl(arg)
    if result.handled:
      return result

  let newArg = arg.withElem(self)
  if self.isPointInside(arg.pos) or self.pointerCaptured():
    elementsHandledPointerMoveThisUpdate.incl(self)
    if self.pointerInsideLastUpdate:
      for handler in self.pointerMovedHandlers:
        let res = handler(arg.withElem(self))
        if res.handled:
          return res
    else:
      self.pointerInsideLastUpdate = true
      for handler in self.pointerEnteredHandlers:
        let res = handler(arg.withElem(self))
        if res.handled:
          return res
  elif self.pointerInsideLastUpdate and not(self.pointerCaptured):
    self.pointerInsideLastUpdate = false
    for handler in self.pointerExitedHandlers:
      let res = handler(arg.withElem(self))
      if res.handled:
        return res

proc dispatchPointerDown*(self: Element, arg: PointerArgs): PointerEventResult =
  elementsHandledPointerDownThisUpdate.clear()
  self.dispatchPointerDownImpl(arg)

proc dispatchPointerUp*(self: Element, arg: PointerArgs): PointerEventResult =
  elementsHandledPointerUpThisUpdate.clear()
  self.dispatchPointerUpImpl(arg)

proc dispatchPointerMove*(self: Element, arg: PointerArgs): PointerEventResult =
  elementsHandledPointerMoveThisUpdate.clear()
  self.dispatchPointerMoveImpl(arg)
