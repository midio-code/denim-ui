
import sugar
import options
import ../behaviors
import ../../events
import ../element
import ../element_events

proc onWheel*(handler: (elem: Element, args: WheelArgs) -> EventResult): Behavior =
  # TODO: Remove behavior when unrooted
  Behavior(
    added: some(
      proc(elem: Element):void =
        elem.onWheel(
          proc(arg: WheelArgs): EventResult =
            echo "WHEEL: ", arg.repr
            handler(elem, arg)
        )
    )
  )
