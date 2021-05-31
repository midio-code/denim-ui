import types
import options
import sequtils
import sugar
import ../events

type
  PointerCaptureChangedArgs* = object
  PointerCapture = tuple[owner: Element, lostCapture: Option[() -> void]]

var pointerCapturedEmitter* = emitter[PointerCaptureChangedArgs]()
var pointerCaptureReleasedEmitter* = emitter[PointerCaptureChangedArgs]()

var pointerCaptures: seq[PointerCapture] = @[]

proc getCaptureFor(self: Element): Option[PointerCapture] =
  for c in pointerCaptures:
    if c.owner == self:
      return some(c)
  none[PointerCapture]()

iterator pointerCaptors*(): Element =
  let caps = pointerCaptures
  for c in caps:
    yield c.owner

proc hasPointerCapture*(self: Element): bool =
  pointerCaptures.any(x => x.owner == self)

proc pointerIsCaptured*(): bool =
  pointerCaptures.len > 0

proc pointerCapturedBySomeoneElse*(self: Element): bool =
  pointerCaptures.len > 0 and not self.hasPointerCapture()

proc releasePointer*(self: Element) =
  if self.hasPointerCapture:
    let capture = getCaptureFor(self)
    pointerCaptures.keepIf(
      proc(capture: PointerCapture): bool =
        capture.owner != self
    )
    if pointerCaptures.len == 0:
      pointerCaptureReleasedEmitter.emit(PointerCaptureChangedArgs())

    if capture.isSome and capture.get.lostCapture.isSome:
      capture.get.lostCapture.get()()

proc capturePointerExclusive*(self: Element, lostCapture: Option[() -> void] = none[() -> void]()): void =
  ## Element captures the pointer and discards any other captures
  if pointerCapturedBySomeoneElse(self):
    echo "WARN: Tried to capture pointer that was already captured by someone else!"

  pointerCaptures = @[(self, lostCapture)]
  pointerCapturedEmitter.emit(PointerCaptureChangedArgs())

proc capturePointerShared*(self: Element, lostCapture: Option[() -> void] = none[() -> void]()): void =
  ## Element captures the pointer but allows for the capture to be shared with other Elements.
  pointerCaptures.add((self, lostCapture))
  pointerCapturedEmitter.emit(PointerCaptureChangedArgs())
