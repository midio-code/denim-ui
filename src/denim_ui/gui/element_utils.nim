import options, sequtils, types

proc bringToFront*(self: Element): void =
  if self.parent.isSome:
    # TODO: We should probably normalize all zIndexes every once in a while.
    let largestZIndex = self.parent.get().children.foldl(max(a, b.props.zIndex.get(0)), low(int))
    # TODO: Do not increase z index if self is already in front
    self.props.zIndex = some(largestZIndex + 1)

proc isAncestorOf*(ancestor: Element, ofElem: Element): bool =
  var current = ofElem
  while current.parent.isSome:
    current = current.parent.get
    if current == ancestor:
      return true
  return false
