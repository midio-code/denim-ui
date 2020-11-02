import sugar
import options
import ../behaviors
import ../../events
import ../element
import ../element_events

proc onPressed*(handler: (elem: Element, args: PointerArgs) -> PointerEventResult): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element):void =
        elem.onPointerPressed(
          proc(arg: PointerArgs): PointerEventResult =
            handler(elem, arg)
        )
    )
  )

proc onReleased*(handler: (elem: Element, args: PointerArgs) -> PointerEventResult): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element): void =
        elem.onPointerReleased(
          proc(arg: PointerArgs): PointerEventResult =
            handler(elem, arg)
        )
    )
  )


proc onPointerMoved*(handler: (elem: Element, args: PointerArgs) -> PointerEventResult): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element):void =
        elem.onPointerMoved(
          proc(arg: PointerArgs): PointerEventResult =
            handler(elem, arg)
        )
    )
  )

# TODO: Remove on unrooted for all relevant behaviors
