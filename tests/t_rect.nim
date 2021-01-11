import denim_ui
import unittest

suite "rect tests":
  echo "Rect test setup"

  test "Intersection":
    let r1 = rect(0,0,10,10)
    let r2 = rect(5,5,20,20)
    check(r1.intersects(r2))

  test "Intersection 2":
      let r1 = rect(0,0,10,10)
      let r2 = rect(10,10,20,20)
      check(r1.intersects(r2))

  test "Not intersecting":
        let r1 = rect(0,0,10,10)
        let r2 = rect(11,11,20,20)
        check(r1.intersects(r2) == false)
