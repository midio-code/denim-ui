import sugar
import options
import rx_nim
import ../behaviors
import ../../events
import ../../vec
import ../element
import ../element_events

proc onDrag*(
  moved: (Vec2[float] -> void),
  pointerIndex: PointerIndex = PointerIndex.Primary,
  canStartDrag: Observable[bool] = behaviorSubject(true)
): Behavior =
  var pastPos = vec2(0.0, 0.0)
  var canCurrentlyStartDrag = true

  Behavior(
    added: some(
      proc(element: Element): void =
        discard canStartDrag.subscribe( # TODO: Dispose subscription
          proc(value: bool) =
            canCurrentlyStartDrag = value
        )

        element.onPointerMoved(
          proc(arg: PointerArgs): EventResult =
            if element.hasPointerCapture():
              let diff = arg.actualPos.sub(pastPos)
              moved(diff)
              pastPos = arg.actualPos
        )
        element.onPointerPressed(
          proc(arg: PointerArgs): EventResult =
            if canCurrentlyStartDrag and arg.pointerIndex == pointerIndex:
              element.capturePointer()
              pastPos = arg.actualPos
              return handled()
        )

        element.onPointerReleased(
          proc(arg: PointerArgs): EventResult =
            if arg.pointerIndex == pointerIndex:
              arg.sender.releasePointer()
        )
    )
  )
