import sugar
import strformat
import options
import tables
import ../behaviors
import ../update_manager
import ../element
import ../element_events
import ../../guid
import ../../vec
import ../../events

type
  ClickedHandler* = (Element, PointerArgs, var EventResult) -> void

let behaviorId = genGuid()

var clickedHandlers = initTable[Element, seq[ClickedHandler]]()

proc onClicked*(handler: ClickedHandler, force: bool = false): Behavior =
  Behavior(
    added: some(
      proc(element: Element): void =
        if not clickedHandlers.hasKey(element):
          var pressed = false

          element.onPointerPressed(
            proc(arg: PointerArgs, res: var EventResult): void =
              if arg.pointerIndex == PointerIndex.Primary:
                pressed = true
          )
          element.onPointerReleased(
            proc(args: PointerArgs, res: var EventResult): void =
              if pressed and (force or not res.isHandled()):
                for handler in clickedHandlers[element]:
                  handler(element, args, res)
              pressed = false
          )

        clickedHandlers.mgetorput(element, @[]).add(handler)
    )
  )

proc onClicked*(handler: () -> void, force: bool = false): Behavior =
  onClicked(
    proc(e: Element, args: PointerArgs, res: var EventResult): void =
      handler(),
    force
  )

proc onClicked*(handler: () -> bool, force: bool = false): Behavior =
  onClicked(
    proc(e: Element, args: PointerArgs, res: var EventResult): void =
      if handler():
        res.addHandledBy(behaviorId)
    ,
    force
  )

let doublecClickedBehaviorId = genGuid()

proc onDoubleClicked*(handler: ClickedHandler, waitMs: float = 500.0, force: bool = false): Behavior =
  var clickedOnce = false
  var lastClick: Vec2[float]
  var dispose: Dispose = nil
  onClicked(
    proc(e: Element, args: PointerArgs, res: var EventResult): void =
      if not res.isHandledByOtherThan(e.id):
        if clickedOnce and lastClick.distanceTo(args.actualPos) < 5.0:
          res.addHandledBy(doublecClickedBehaviorId)
          handler(e, args, res)
          clickedOnce = false
          if not isNil(dispose):
            dispose()
        else:
          clickedOnce = true
          lastClick = args.actualPos
          dispose = wait(
            proc() =
              clickedOnce = false
              lastClick = nil,
          waitMs)
  )

proc onDoubleClicked*(handler: () -> void, waitMs: float = 500.0, force: bool = false): Behavior =
  onDoubleClicked(
    proc(e: Element, args: PointerArgs, res: var EventResult): void =
      handler(),
    waitMs,
    force
  )
