import tables
import sugar
import element
import options
import ../utils

type
  Behavior* = object
    update*: Option[(elem: Element, dt: float) -> void]
    added*: Option[(elem: Element) -> void]
    # removed*: Option[(elem: Element) -> void]


var behaviors_list = initTable[Element, seq[Behavior]]()

proc dispatchUpdate*(self: Element, dt: float): bool =
  for child in self.children:
    let stopBubbling = child.dispatchUpdate(dt)
    if stopBubbling:
      return stopBubbling
  if self.isRooted() and behaviors_list.hasKey(self):
    for behavior in behaviors_list[self]:
      if behavior.update.isSome():
        behavior.update.get()(self, dt)
  return false

proc add*(element: Element, behavior: Behavior): void =
  behaviors_list.mgetOrPut(element, @[]).add(behavior)
  if behavior.added.isSome():
    behavior.added.get()(element)

proc behaviors*(element: Element): seq[Behavior] =
  if not behaviors_list.hasKey(element):
    return @[]
  behaviors_list[element]
