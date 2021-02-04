import sugar
import options
import tables
import ../behaviors
import ../element
import ../element_events
import ../../guid
import ../../events

type
  ClickedHandler* = (Element, PointerArgs) -> void

var clickedHandlers = initTable[Element, seq[ClickedHandler]]()

proc onClicked*(handler: ClickedHandler): Behavior =
  Behavior(
    added: some(
      proc(element: Element): void =
        if not clickedHandlers.hasKey(element):
          let id = genGuid()
          var pressed = false

          proc onLostCapture() =
            pressed = false

          element.onPointerPressed(
            proc(arg: PointerArgs): EventResult =
              element.capturePointer()
              pressed = true
          )
          element.onPointerReleased(
            proc(args: PointerArgs): EventResult =
              if pressed and element.hasPointerCapture:
                pressed = false
                element.capturePointer()
                element.releasePointer()
                for handler in clickedHandlers[element]:
                  handler(element, args)
          )

        clickedHandlers.mgetorput(element, @[]).add(handler)
    )
  )
