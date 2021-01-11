import unittest, options, sugar
import denim_ui
import testutils

suite "Element observable tests":
  discard
  # test "Observe bounds of an element":

  #   let e2 = panel()
  #   let observedBounds = e2.observeBounds()

  #   let er = root:
  #     panel(width = 500.0, height = 200.0):
  #       e2

  #   let val = behaviorSubject(observedBounds)

  #   er.dispatchOnRooted()
  #   invalidateWorldPositionsCache()
  #   er.invalidateLayout()
  #   performOutstandingLayoutsAndMeasures(rect(0.0, 0.0, 500.0, 500.0))

  #   check(val.value.width == 500.0)
  #   check(val.value.height == 200.0)

  #   er.addChild(panel(height = 300.0))
  #   er.invalidateLayout()
  #   performOutstandingLayoutsAndMeasures(rect(0.0, 0.0, 500.0, 500.0))
  #   check(val.value.width == 500.0)
  #   check(val.value.height == 300.0)
