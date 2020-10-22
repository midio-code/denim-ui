import sugar, tables, options
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
  proc `emit name`(self: Element, args: T): void =
    if eventTable.hasKey(self):
      var e = eventTable[self]
      for handler in e:
        discard handler(args)
  # proc `observe name`*(self: Element): Observable[T] =
  #   eventTable[self].toObservable()

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

proc dispatchPointerDown*(self: Element, arg: PointerArgs): PointerEventResult =
  if self.props.visibility == Visibility.Collapsed:
    return
  for child in self.children.reverse():
    let result = child.dispatchPointerDown(arg)
    if result.handled:
       return result
  # TODO: Return bool instead of mutating arg
  if self.isPointInside(arg.pos): # or self.pointerCaptured:
    echo "Emitting pointer down"
    self.emitPointerPressed(arg.withElem(self))

proc dispatchPointerUp*(self: Element, arg: PointerArgs): PointerEventResult =
  if self.props.visibility == Visibility.Collapsed:
    return

  for child in self.children.reverse():
    let result = child.dispatchPointerUp(arg)
    if result.handled:
      return result
  if (self.isPointInside(arg.pos) or self.pointerCaptured()):
    self.emitPointerReleased(arg.withElem(self))

proc dispatchPointerMove*(self: Element, arg: PointerArgs): PointerEventResult =
  if self.props.visibility == Visibility.Collapsed:
    return
  for child in self.children.reverse():
    result = child.dispatchPointerMove(arg)
    if result.handled:
      return result

  let newArg = arg.withElem(self)
  if self.isPointInside(arg.pos) or self.pointerCaptured():
    if self.pointerInsideLastUpdate:
      self.emitPointerMoved(newArg)
    else:
      self.pointerInsideLastUpdate = true
      echo "emitting etnered"
      self.emitPointerEntered(newArg)
  elif self.pointerInsideLastUpdate and not(self.pointerCaptured):
    self.pointerInsideLastUpdate = false
    self.emitPointerExited(newArg)
