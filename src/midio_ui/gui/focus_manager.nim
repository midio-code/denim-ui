import types
import options
import rx_nim

let focusedElementSubject = behaviorSubject[Option[Element]]()

proc nextSibling(self: Element): Option[Element] =
  if self.parent.isSome:
    let parent = self.parent.get()
    let myIndex = parent.children.find(self)
    if parent.children.len > myIndex + 1:
      return some(parent.children[myIndex + 1])
  none[Element]()

proc giveFocus*(self: Element): void =
  focusedElementSubject <- some(self)

proc focusNext*(): void =
  if focusedElementSubject.value.isSome:
    focusedElementSubject <- focusedElementSubject.value.get.nextSibling


proc clearFocus*(): void =
  focusedElementSubject <- none[Element]()

proc releaseFocus*(self: Element): void =
  if focusedElementSubject.value.isSome and focusedElementSubject.value.get == self:
    clearFocus()

let focusedElement* = focusedElementSubject.source

proc hasFocus*(self: Element): Observable[bool] =
  focusedElement.map(
    proc(f: Option[Element]): bool =
      f.isSome and f.get() == self
  )
