import denim_ui
import unittest

suite "Element bounds":
  test "World bounds expensive":
    let child = panel(x = 50, y = 50, width = 50, height = 50, transform = @[scale(vec2(2.0))])
    let root =
      panel(width = 500, height = 500):
        child

    root.addTag("root")
    root.dispatchOnRooted()
    root.invalidateLayout()
    performOutstandingLayoutsAndMeasures(rect(0.0, 0.0, 500.0, 500.0))
    root.recalculateWorldPositionsCache()

    let worldBounds = child.worldBoundsExpensive()
    check(worldBounds.scale == vec2(2.0))
    check(worldBounds.bounds.pos == vec2(50.0, 50.0))
    check(worldBounds.bounds.size == vec2(100.0, 100.0))
