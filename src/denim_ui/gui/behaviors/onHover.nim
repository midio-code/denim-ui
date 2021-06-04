import sugar
import options
import rx_nim
import ../behaviors
import ../element
import ../element_events
import ../../guid
import ../../events

let hoverBehaviorId = genGuid()

proc onHover*(entered: (Element) -> bool, exited: (Element) -> bool, force: bool = false): Behavior =
  Behavior(
    added: some(
      proc(element: Element): void =
        element.onPointerEntered(
          proc(arg: PointerArgs, res: var EventResult): void =
            if force or not res.isHandled:
              if entered(element):
                res.addHandledBy(hoverBehaviorId)
        )
        element.onPointerExited(
          proc(arg: PointerArgs, res: var EventResult): void =
            if force or not res.isHandled:
              if exited(element):
                res.addHandledBy(hoverBehaviorId)
        )
    )
  )

proc onHover*(entered: (Element) -> void, exited: (Element) -> void): Behavior =
  onHover(
    proc(e: Element): bool =
      entered(e)
      false,
    proc(e: Element): bool =
      exited(e)
      false
  )

proc onHover*(entered: (Element) -> bool, force: bool = false): Behavior =
  Behavior(
    added: some(
      proc(element: Element):void =
        element.onPointerEntered(
          proc(arg: PointerArgs, res: var EventResult): void =
            if force or not res.isHandled:
              if entered(element):
                res.addHandledBy(hoverBehaviorId)
        )
    )
  )


proc onHover*(entered: (Element) -> void): Behavior =
  onHover(
    proc(e: Element): bool =
      entered(e)
      false
  )


template toggleOnHover*(toggler: untyped): untyped =
  onHover(
    proc(e: Element): bool =
      toggler
      true
    ,
    proc(e: Element): bool =
      toggler
      true
  )

proc toggleOnHover*(subj: Subject[bool], force: bool = false): Behavior =
  onHover(
    proc(e: Element): bool =
      subj <- true
      true
    ,
    proc(e: Element): bool =
      subj <- false
      true
    ,
    force
  )
