import sugar
import options
import ../behaviors
import ../../events
import ../element
import ../element_events

proc onPressed*(handler: (elem: Element) -> PointerEventResult): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element):void =
        elem.onPointerPressed(
          proc(arg: PointerArgs): PointerEventResult =
            handler(elem)
        )
    )
  )

proc onReleased*(handler: (elem: Element) -> PointerEventResult): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element): void =
        elem.onPointerReleased(
          proc(arg: PointerArgs): PointerEventResult =
            handler(elem)
        )
    )
  )


proc onPointerMoved*(handler: (elem: Element, pos: Point) -> PointerEventResult): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element):void =
        elem.onPointerMoved(
          proc(arg: PointerArgs): PointerEventResult =
            handler(elem, arg.pos)
        )
    )
  )

# TODO: Remove on unrooted for all relevant behaviors
