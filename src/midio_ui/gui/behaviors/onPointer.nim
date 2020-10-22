import sugar
import options
import ../behaviors
import ../../events
import ../element
import ../element_events

proc onPressed*(handler: (elem: Element) -> void): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element):void =
        elem.onPointerPressed(
          proc(arg: PointerArgs): PointerEventResult =
            handler(elem)
            handled()
        )
    )
  )

proc onReleased*(handler: (elem: Element) -> void): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element):void =
        elem.onPointerReleased(
          proc(arg: PointerArgs): PointerEventResult =
            handler(elem)
            handled()
        )
    )
  )


proc onPointerMoved*(handler: (elem: Element, pos: Point) -> void): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element):void =
        elem.onPointerMoved(
          proc(arg: PointerArgs): PointerEventResult =
            handler(elem, arg.pos)
            handled()
        )
    )
  )

# TODO: Remove on unrooted for all relevant behaviors
