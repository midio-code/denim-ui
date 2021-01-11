import tables, options
import types
import ../events
import ../rect

type
  BoundsChangedHandler = proc(newBounds: Rect[float]): void
  BoundsChangedEmitter = EventEmitter[Rect[float]]

var boundsChangedHandlers = initTable[Element, BoundsChangedEmitter]()
var scheduledEvents: seq[tuple[elem: Element, bounds: Bounds]] = @[]

proc onBoundsChanged*(self: Element, handler: BoundsChangedHandler): void =
  boundsChangedHandlers.mgetOrPut(self, emitter[Rect[float]]()).add(handler)

proc scheduleBoundsChangeEventForNextFrame*(self: Element): void =
  if boundsChangedHandlers.contains(self):
    scheduledEvents.add((self, self.bounds.get()))

proc emitBoundsChangedEventsFromPreviousFrame*(): void =
  for ev in scheduledEvents:
    if boundsChangedHandlers.contains(ev.elem):
      boundsChangedHandlers[ev.elem].emit(ev.bounds)
  scheduledEvents = @[]
