import denim_ui
import unittest
import testutils

template expectLayoutWithoutPerforming(self: Element, tests: varargs[Rect[float]]): untyped =
  var i = 0
  for test in tests:
    let bounds = self.children[i].bounds.get()
    check(bounds == test)
    i+=1

template expectLayout(self: Element, tests: varargs[Rect[float]]): untyped =
  self.dispatchOnRooted()
  invalidateWorldPositionsCache()
  self.invalidateLayout()
  performOutstandingLayoutsAndMeasures(rect(0.0, 0.0, 500.0, 500.0))
  var i = 0
  for test in tests:
    let bounds = self.children[i].bounds.get()
    check(bounds == test)
    i+=1

proc box(): Element =
  panel(width = 50.0, height = 50.0)

suite "Layout tests - panel":
  test "Panel":
    var p = root:
      panel(width = 500, height = 500):
        box()
    p.expectLayout(rect(225.0, 225.0, 275.0, 275.0))

  test "Panel alignment top left":
    var topLeft = root:
      panel(width = 500, height = 500):
        panel(width = 50, height = 50, alignment = Alignment.TopLeft)
    topLeft.expectLayout(rect(0.0, 0.0, 50.0, 50.0))

  test "Panel alignment top right":
    var topRight = root:
      panel(width = 500, height = 500):
        panel(width = 50, height = 50, alignment = Alignment.TopRight)
    topRight.expectLayout(rect(450.0, 0.0, 500.0, 50.0))

  test "Panel alignment bottom left":
    var bottomLeft = root:
      panel(width = 500, height = 500):
        panel(width = 50, height = 50, alignment = Alignment.BottomLeft)
    bottomLeft.expectLayout(rect(0.0, 450.0, 50.0, 500.0))

  test "Panel alignment bottom right":
    var bottomRight = root:
      panel(width = 500, height = 500):
        panel(width = 50, height = 50, alignment = Alignment.BottomRight)
    bottomRight.expectLayout(rect(450.0, 450.0, 500.0, 500.0))

  test "Panel alignment center left":
    var left = root:
      panel(width = 500, height = 500):
        panel(width = 50, height = 50, alignment = Alignment.CenterLeft)
    left.expectLayout(rect(0.0, 225.0, 50.0, 275.0))

  test "Panel alignment center right":
    var right = root:
      panel(width = 500, height = 500):
        panel(width = 50, height = 50, alignment = Alignment.CenterRight)
    right.expectLayout(rect(450.0, 225.0, 500.0, 275.0))

  test "Panel alignment bottom center":
    var right = root:
      panel(width = 500, height = 500):
        panel(width = 50, height = 50, alignment = Alignment.BottomCenter)
    right.expectLayout(rect(225.0, 450.0, 275.0, 500.0))

  test "Panel alignment top center":
    var right = root:
      panel(width = 500, height = 500):
        panel(width = 50, height = 50, alignment = Alignment.TopCenter)
    right.expectLayout(rect(225.0, 0.0, 275.0, 50.0))


suite "Alignment tests":
  test "Center box":
    let p = root:
      panel(width = 500, height = 500):
        panel(alignment = Alignment.Center):
          rectangle(width = 50.0, height = 50.0)
    p.expectLayout(rect(225.0, 225.0, 275.0, 275.0))


suite "Layout tests - stack":
  test "Vertical stack":
    var p = root:
      stack(width = 500, height = 500):
        box()
        box()
        box()
    p.expectLayout(
      rect(225.0, 0.0, 275.0, 50.0),
      rect(225.0, 50.0, 275.0, 100.0),
      rect(225.0, 100.0, 275.0, 150.0)
    )

  test "Horizontal stack":
    var p = root:
      stack(direction = StackDirection.Horizontal, width = 500, height = 500):
        box()
        box()
        box()
    p.expectLayout(
      rect(0.0, 225.0, 50.0, 275.0),
      rect(50.0, 225.0, 100.0, 275.0),
      rect(100.0, 225.0, 150.0, 275.0)
    )

suite "Layout tests - dock":
  test "Dock box left with fill rest":
    let p = root:
      dock(width = 500.0, height = 500.0):
        docking(DockDirection.Left):
          box()
        panel()
    p.expectLayout(rect(0.0, 225.0, 50.0, 275.0), rect(50.0, 0.0, 500.0, 500.0))


  test "Dock box right with fill rest":
    let p = root:
      dock(width = 500.0, height = 500.0):
        docking(DockDirection.Right):
          box()
        panel()
    p.expectLayout(rect(450.0, 225.0, 500.0, 275.0), rect(0.0, 0.0, 450.0, 500.0))

  test "Dock top with stretch":
    let p = root:
      dock(width = 500.0, height = 500.0):
        docking(DockDirection.Top):
          panel(height = 100.0)
        panel()
    p.expectLayout(rect(0.0, 0.0, 500.0, 100.0), rect(0.0, 100.0, 500.0, 500.0))

  test "Dock right with stretch":
    let p = root:
      dock(width = 500.0, height = 500.0):
        docking(DockDirection.Right):
          panel(width = 100.0)
        panel()
    p.expectLayout(rect(400.0, 0.0, 500.0, 500.0), rect(0.0, 0.0, 400.0, 500.0))

  test "Dock stretching":
    let p = root:
      panel(width = 500.0, height = 500.0):
        dock():
          docking(DockDirection.Top):
            panel(height = 100.0)
          panel()

    p.expectLayout(rect(0.0, 0.0, 500.0, 500.0))
    p.children[0].expectLayoutWithoutPerforming(rect(0.0, 0.0, 500.0, 100.0), (rect(0.0, 100.0, 500.0, 500.0)))

  test "Dock stretch 2":
    let p = root:
      dock():
        docking(DockDirection.Top):
          panel(height = 100.0)
        panel()

    p.expectLayout(rect(0.0, 0.0, 500.0, 100.0), (rect(0.0, 100.0, 500.0, 500.0)))
