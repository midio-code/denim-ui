import sugar
import options
import ../behaviors
import ../../events
import ../element
import ../element_events

proc onKeyDown*(
  key: string,
  handler: (Element, KeyArgs) -> void
): Behavior =
  Behavior(
    added: some(
      proc(element: Element): void =
        onKeyDownGlobal(
          proc(event: KeyArgs) =
            if event.key == key:
              handler(element, event)
        )
    )
  )

proc onKeyUp*(
  key: string,
  handler: (Element, KeyArgs) -> void
): Behavior =
  Behavior(
    added: some(
      proc(element: Element): void =
        onKeyUpGlobal(
          proc(event: KeyArgs) =
            if event.key == key:
              handler(element, event)
        )
    )
  )

proc onKey*(
  key: string,
  down: (Element, KeyArgs) -> void,
  up: (Element, KeyArgs) -> void
): Behavior =
  Behavior(
    added: some(
      proc(element: Element): void =
        onKeyDownGlobal(
          proc(event: KeyArgs) =
            if event.key == key:
              down(element, event)
        )
        onKeyUpGlobal(
          proc(event: KeyArgs) =
            if event.key == key:
              up(element, event)
        )
    )
  )
