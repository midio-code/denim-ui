import tables, options
import types
import ../events
import ../rect

type
  BoundsChangedHandler = proc(newBounds: Rect[float]): void
  BoundsChangedEmitter = EventEmitter[Rect[float]]

var boundsChangedHandlers = initTable[Element, BoundsChangedEmitter]()

proc onBoundsChanged*(self: Element, handler: BoundsChangedHandler): void =
  boundsChangedHandlers.mgetOrPut(self, emitter[Rect[float]]()).add(handler)

proc emitOnBoundsChanged*(self: Element): void =
  if boundsChangedHandlers.contains(self):
    boundsChangedHandlers[self].emit(self.bounds.get())
