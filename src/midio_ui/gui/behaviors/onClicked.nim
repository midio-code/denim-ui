import sugar
import options
import ../behaviors
import ../../events
import ../element
import ../element_events

proc onClicked*(handler: (elem: Element) -> void): Behavior =
  Behavior(
    added: some(
      proc(element: Element): void =
        element.onPointerPressed(
          proc(arg: PointerArgs): PointerEventResult =
            element.capturePointer()
        )
        element.onPointerReleased(
          proc(arg: PointerArgs): PointerEventResult =
            if element.hasPointerCapture():
              element.releasePointer()
            handler(element)
        )
    )
  )
