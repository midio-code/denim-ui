import types, tables, ../vec, rx_nim, options

# TODO: This is probably not a robust way to cache this, and is just a
# proof of concept for caching values that depends on layout calculations
var worldPositions = initTable[Element, Vec2[float]]()

var worldPositionObservers = initTable[Element, Subject[Point]]()

proc actualWorldPosition*(self: Element): Vec2[float] =
  worldPositions.mgetorput(self, zero())

proc observeWorldPosition*(self: Element): Observable[Vec2[float]] =
  worldPositionObservers.mgetorput(self, subject[Vec2[float]]()).unique

proc recalculateWorldPositionsCache*(root: Element): void =
  worldPositions.clear()
  proc calcWorldPos(elem: Element, parentPos: Point): void =
    let elemPos = elem.bounds.get().pos + parentPos
    worldPositions[elem] = elemPos
    if elem in worldPositionObservers:
      worldPositionObservers[elem] <- elemPos
    for c in elem.children:
      c.calcWorldPos(elemPos)
  root.calcWorldPos(zero())
