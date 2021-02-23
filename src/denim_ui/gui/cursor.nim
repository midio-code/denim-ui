import sugar
import options
import types
import element_events
import behaviors
import behaviors/onHover

type
  Cursor* {.pure.} = enum
    Default, Clickable, Dragging

var setCursor*: (Cursor) -> void = nil
var lastToSetCursor = none[Element]()

proc cursorOnHover*(cursor: Cursor): Behavior =
  onHover(
    proc(elem: Element): void =
      setCursor(cursor)
      lastToSetCursor = some(elem),
    proc(elem: Element): void =
      if lastToSetCursor.isSome and lastToSetCursor.get == elem:
        setCursor(Cursor.Default)
        lastToSetCursor = none[Element]()
  )

proc cursorWhilePressed*(cursor: Cursor, pointerIndex: PointerIndex): Behavior =
  Behavior(
    added: some(
      proc(element: Element): void =
        element.onPointerPressed(
          proc(arg: PointerArgs, res: var EventResult): void =
            if arg.pointerIndex == pointerIndex:
              setCursor(Cursor.Dragging)
              lastToSetCursor = some(element)
        )
        element.onPointerReleased(
          proc(arg: PointerArgs, res: var EventResult): void =
            if arg.pointerIndex == pointerIndex and lastToSetCursor.isSome and lastToSetCursor.get == element:
              setCursor(Cursor.Default)
              lastToSetCursor = none[Element]()
        )
    )
  )
