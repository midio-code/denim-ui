import sugar
import options
import ../behaviors
import ../../events
import ../element
import ../element_events

proc onHover*(entered: (Element) -> void, exited: (Element) -> void): Behavior =
  Behavior(
    added: some(
      proc(element: Element):void =
        element.onPointerEntered(
          proc(arg: PointerArgs): void =
            entered(element)
        )
        element.onPointerExited(
          proc(arg: PointerArgs): void =
            exited(element)
        )
    )
  )

proc onHover*(entered: (Element) -> void): Behavior =
  Behavior(
    added: some(
      proc(element: Element):void =
        element.onPointerEntered(
          proc(arg: PointerArgs): void =
            entered(element)
        )
    )
  )
