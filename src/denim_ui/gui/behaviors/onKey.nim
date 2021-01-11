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
        keyDownEmitter.add(
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
        keyUpEmitter.add(
          proc(event: KeyArgs) =
            if event.key == key:
              handler(element, event)
        )
    )
  )
