
import sugar
import options
import ../behaviors
import ../../events
import ../element
import ../element_events

proc onWheel*(handler: (elem: Element, args: WheelArgs, res: var EventResult) -> void): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element):void =
        elem.onWheel(
          proc(arg: WheelArgs, res: var EventResult): void =
            if not res.isHandled:
              handler(elem, arg, res)
              res.addHandledBy(elem.id, "onWheel")
        )
    )
  )
