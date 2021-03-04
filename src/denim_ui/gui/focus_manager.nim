import types
import sugar
import options
import rx_nim

let focusedElementSubject = behaviorSubject[Option[(Element, Option[() -> void])]]()

proc getCurrentlyFocusedElement*(): Option[Element] =
  if focusedElementSubject.value.isSome:
    some(focusedElementSubject.value.get[0])
  else:
    none[Element]()

proc nextSibling(self: Element): Option[Element] =
  if self.parent.isSome:
    let parent = self.parent.get()
    let myIndex = parent.children.find(self)
    if parent.children.len > myIndex + 1:
      return some(parent.children[myIndex + 1])

proc giveFocus*(self: Element, lostFocusHandler: Option[() -> void] = none[() -> void]()): void =
  focusedElementSubject <- some((self, lostFocusHandler))

proc focusNext*(): void =
  if focusedElementSubject.value.isSome:
    let focusItem = focusedElementSubject.value.get
    if focusItem[1].isSome:
      focusItem[1].get()()
    let next = focusedElementSubject.value.get()[0].nextSibling
    if next.isSome:
      focusedElementSubject <- some((next.get(), none[() -> void]()))
    else:
      focusedElementSubject <- none[(Element, Option[() -> void])]()

proc clearFocus*(): void =
  if focusedElementSubject.value.isSome and focusedElementSubject.value.get[1].isSome:
    focusedElementSubject.value.get[1].get()()
  focusedElementSubject <- none[(Element, Option[() -> void])]()

proc releaseFocus*(self: Element): void =
  if focusedElementSubject.value.isSome and focusedElementSubject.value.get[0] == self:
    clearFocus()

let focusedElement* = focusedElementSubject.source

proc hasFocus*(self: Element): Observable[bool] =
  focusedElement.map(
    proc(f: Option[(Element, Option[() -> void])]): bool =
      f.isSome and f.get()[0] == self
  ).distinctUntilChanged

proc isFocused*(self: Element): bool =
  focusedElementSubject.value.isSome and focusedElementSubject.value.get[0] == self
