import sugar
import options
import ../behaviors
import ../../events
import ../element
import ../element_events

proc onClicked*(handler: (elem: Element, args: PointerArgs) -> void): Behavior =
  var pressed = false
  Behavior(
    added: some(
      proc(element: Element): void =
        element.onPointerPressed(
          proc(arg: PointerArgs): EventResult =
            pressed = true
        )
        element.onPointerReleased(
          proc(args: PointerArgs): EventResult =
            if pressed:
              handler(element, args)
            pressed = false
        )
    )
  )
