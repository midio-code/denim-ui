import strformat, sugar, unittest
import midio_ui
import testutils

suite "Element events":
  test "Pointer events sanity check":

    let p = panel(width = 500.0, height = 500.0)
    let e = root:
      p
    var c = false
    p.onPointerMoved(
      proc(pos: PointerArgs): void =
        c = true
    )
    p.invalidateLayout()
    performOutstandingLayoutsAndMeasures(rect(0.0, 0.0, 500.0, 500.0))
    p.calculateWorldPositions()
    e.dispatchPointerMove(e.pointerArgs(vec2(220.0, 220.0)))
    e.dispatchPointerMove(e.pointerArgs(vec2(250.0, 250.0)))
    check(c)
