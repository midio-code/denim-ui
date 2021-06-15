import sugar
import strformat
import options
import types
import element_events
import behaviors
import behaviors/onHover
import behaviors/onKey
import ../guid

type
  Cursor* {.pure.} = enum
    Default, Clickable, Dragging

var setCursor*: (Cursor) -> void = nil

type
  CursorItem = ref object
    cursor: Cursor
    owner: Element

proc `$`(self: CursorItem): string =
  &"CursorItem: {self.owner.id} -> {self.cursor}"

var cursorStack: seq[CursorItem] = @[]

proc setCursorToTopOfCursorStack(): void =
  if cursorStack.len == 0:
    setCursor(Cursor.Default)
  else:
    setCursor(cursorStack[cursorStack.len - 1].cursor)

proc pushCursor*(cursor: Cursor, owner: Element): void =
  cursorStack.add(
    CursorItem(
      cursor: cursor,
      owner: owner
    )
  )
  setCursorToTopOfCursorStack()

proc popDownToElement*(owner: Element): void =
  while cursorStack.len > 0 and cursorStack[cursorStack.len - 1].owner != owner:
    discard cursorStack.pop()
  setCursorToTopOfCursorStack()

proc cursorOnHover*(cursor: Cursor): Behavior =
  onHover(
    proc(elem: Element): void =
      pushCursor(cursor, elem),
    proc(elem: Element): void =
      popDownToElement(elem.parent.get)
  )

let cursorWhilePressedBehaviorId = genGuid()
proc cursorWhilePressed*(cursor: Cursor, pointerIndex: PointerIndex): Behavior =
  Behavior(
    added: some(
      proc(element: Element): void =
        var didPushCursor = false
        element.onPointerPressed(
          proc(arg: PointerArgs, res: var EventResult): void =
            if not res.isHandledBy(cursorWhilePressedBehaviorId) and arg.pointerIndex == pointerIndex:
              res.addHandledBy(cursorWhilePressedBehaviorId, "cursorWhilePress")
              didPushCursor = true
              pushCursor(cursor, element)
        )
        onPointerReleasedGlobal(
          proc(arg: PointerArgs): void =
            if didPushCursor and arg.pointerIndex == pointerIndex:
              popDownToElement(element)
              didPushCursor = false
        )
    )
  )

proc cursorWhileKeyGlobal*(cursor: Cursor, key: string): Behavior =
  var didPushCursor = true
  onKeyGlobal(
    key,
    proc(element: Element, args: KeyArgs): void =
      pushCursor(cursor, element)
      didPushCursor = true
    ,
    proc(element: Element, args: KeyArgs): void =
      didPushCursor = false
      popDownToElement(element)
  )
