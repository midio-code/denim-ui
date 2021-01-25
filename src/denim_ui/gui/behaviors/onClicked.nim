import sugar
import options
import ../behaviors
import ../../events
import ../../guid
import ../element
import ../element_events

proc onClicked*(handler: (elem: Element, args: PointerArgs) -> void): Behavior =
  Behavior(
    added: some(
      proc(element: Element): void =
        let id = genGuid()
        var pressed = false

        proc onLostCapture() =
          pressed = false

        element.onPointerPressed(
          proc(arg: PointerArgs): EventResult =
            pressed = element.capturePointer(id, CaptureKind.Soft, onLostCapture)
        )
        element.onPointerReleased(
          proc(args: PointerArgs): EventResult =
            if pressed:
              element.releasePointer(id)
              pressed = false
              handler(element, args)
        )
    )
  )
