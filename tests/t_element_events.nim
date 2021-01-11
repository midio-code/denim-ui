import strformat, sugar, unittest
import denim_ui
import testutils

suite "Element events":
  test "Pointer events sanity check":

    let p = panel(width = 500.0, height = 500.0)
    let e = root:
      p
    e.dispatchOnRooted()
    var c = false
    p.onPointerMoved(
      proc(pos: PointerArgs): EventResult =
        c = true
    )
    p.invalidateLayout()
    performOutstandingLayoutsAndMeasures(rect(0.0, 0.0, 500.0, 500.0))
    discard e.dispatchPointerMove(e.pointerArgs(vec2(220.0, 220.0), PointerIndex.Primary))
    discard e.dispatchPointerMove(e.pointerArgs(vec2(250.0, 250.0), PointerIndex.Primary))
    check(c)
