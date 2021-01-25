import sugar
import options
import rx_nim
import ../behaviors
import ../../events
import ../../vec
import ../../guid
import ../element
import ../element_events

proc onDrag*(
  moved: (Vec2[float] -> void),
  pointerIndex: PointerIndex = PointerIndex.Primary,
  canStartDrag: Observable[bool] = behaviorSubject(true)
): Behavior =

  Behavior(
    added: some(
      proc(element: Element): void =
        let id = genGuid()

        var pastPos = vec2(0.0, 0.0)
        var canCurrentlyStartDrag = true
        var pressed = false

        discard canStartDrag.subscribe( # TODO: Dispose subscription
          proc(value: bool) =
            canCurrentlyStartDrag = value
        )

        proc onLostCapture() =
          pressed = false

        element.onPointerMoved(
          proc(arg: PointerArgs): EventResult =
            if pressed:
              discard element.capturePointer(id, CaptureKind.Hard, onLostCapture)
              let diff = arg.actualPos.sub(pastPos)
              moved(diff)
              pastPos = arg.actualPos
        )
        element.onPointerPressed(
          proc(arg: PointerArgs): EventResult =
            if canCurrentlyStartDrag and arg.pointerIndex == pointerIndex:
              pastPos = arg.actualPos
              pressed = element.capturePointer(id, CaptureKind.Soft, onLostCapture)
              return handled()
        )

        element.onPointerReleased(
          proc(arg: PointerArgs): EventResult =
            if arg.pointerIndex == pointerIndex:
              element.releasePointer(id)
              pressed = false
        )
    )
  )
