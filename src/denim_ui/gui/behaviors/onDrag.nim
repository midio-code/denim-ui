import sugar
import options
import rx_nim
import ../behaviors
import ../../events
import ../../vec
import ../../guid
import ../element
import ../element_events

let behaviorId = genGuid()

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

        element.onPointerPressed(
          proc(arg: PointerArgs, res: var EventResult): void =
            if canCurrentlyStartDrag and arg.pointerIndex == pointerIndex:
              pastPos = arg.actualPos
              pressed = true
        )
        element.onPointerMoved(
          proc(arg: PointerArgs, res: var EventResult): void =
            if pressed:
              element.capturePointer(behaviorId, some(onLostCapture))
              let diff = arg.actualPos.sub(pastPos)
              moved(diff)
              pastPos = arg.actualPos
              res.addHandledBy(behaviorId)
        )
        element.onPointerReleased(
          proc(arg: PointerArgs, res: var EventResult): void =
            if arg.pointerIndex == pointerIndex:
              element.releasePointer(behaviorId)
              pressed = false
        )
    )
  )
