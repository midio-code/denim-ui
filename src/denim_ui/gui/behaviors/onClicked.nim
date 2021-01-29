import sugar
import options
import tables
import ../behaviors
import ../../events
import ../../guid
import ../element
import ../element_events

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
              pressed = element.capturePointer(id, CaptureKind.Soft, onLostCapture)
          )
          element.onPointerReleased(
            proc(args: PointerArgs): EventResult =
              if pressed and element.hasPointerCapture:
                pressed = false
                discard element.capturePointer(id, CaptureKind.Hard)
                element.releasePointer(id)
                for handler in clickedHandlers[element]:
                  handler(element, args)
          )

        clickedHandlers.mgetorput(element, @[]).add(handler)
    )
  )
