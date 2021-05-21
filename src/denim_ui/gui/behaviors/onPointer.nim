import sugar
import options
import rx_nim
import ../behaviors
import ../../events
import ../element
import ../element_events

proc onPressed*(handler: (elem: Element, args: PointerArgs, res: var EventResult) -> void): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element):void =
        elem.onPointerPressed(
          proc(arg: PointerArgs, res: var EventResult): void =
            handler(elem, arg, res)
        )
    )
  )

proc onReleased*(handler: (elem: Element, args: PointerArgs, res: var EventResult) -> void): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element): void =
        elem.onPointerReleased(
          proc(arg: PointerArgs, res: var EventResult): void =
            handler(elem, arg, res)
        )
    )
  )


proc onPointerMoved*(handler: (elem: Element, args: PointerArgs, res: var EventResult) -> void): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element):void =
        elem.onPointerMoved(
          proc(arg: PointerArgs, res: var EventResult): void =
            handler(elem, arg, res)
        )
    )
  )

# TODO: Remove on unrooted for all relevant behaviors

template toggleOnPress*(toggler: untyped): untyped =
  Behavior(
    added: some(
      proc(elem: Element):void =
        elem.onPointerPressed(
          proc(arg: PointerArgs, res: var EventResult): void =
            toggler
        )
        elem.onPointerReleased(
          proc(arg: PointerArgs, res: var EventResult): void =
            toggler
        )
    )
  )

proc toggleOnPress*(subj: Subject[bool]): Behavior =
  Behavior(
    added: some(
      proc(elem: Element):void =
        elem.onPointerPressed(
          proc(arg: PointerArgs, res: var EventResult): void =
            subj <- true
        )
        onPointerReleasedGlobal(
          proc(arg: PointerArgs): void =
            subj <- false
        )
    )
  )
