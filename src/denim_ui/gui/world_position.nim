import types, tables, ../vec, rx_nim, options, sugar

# TODO: This is probably not a robust way to cache this, and is just a
# proof of concept for caching values that depends on layout calculations
var worldPositions = initTable[Element, Vec2[float]]()

var worldPositionObservers = initTable[Element, Subject[Option[Point]]]()

proc calcWorldPosInner(elem: Element, parentPos: Point): void =
  if elem.bounds.isSome:
    let elemPos = elem.bounds.get().pos + parentPos
    worldPositions[elem] = elemPos
    if elem in worldPositionObservers:
      worldPositionObservers[elem] <- some(elemPos)
    for c in elem.children:
      c.calcWorldPosInner(elemPos)

proc recalculateWorldPositionsCache*(root: Element): void =
  worldPositions.clear()
  root.calcWorldPosInner(zero())

proc actualWorldPosition*(self: Element): Vec2[float] =
  if self in worldPositions:
    return worldPositions[self]
  else:
    result = self.bounds.map((b: Bounds) => b.pos).get(zero()) + self.parent.map(p => p.actualWorldPosition).get(zero())
    worldPositions[self] = result
    if self in worldPositionObservers:
      worldPositionObservers[self] <- some(result)

proc observeWorldPosition*(self: Element): Observable[Point] =
  worldPositionObservers.mgetorput(self, behaviorSubject[Option[Point]](some(self.actualWorldPosition))).source.unwrap.unique
