import strformat
import unittest
import midio_ui
import midio_ui/gui/update_manager
import sugar

suite "Animations":
  test "Animate float":
    let animator = createAnimator(1000.0)
    var value = 0.0
    let subj = behaviorSubject(animator.value)

    var isDone = false

    animator.start(proc() = isDone = true)

    dispatchUpdate(10.0)
    check(subj.value == 0.01)
    dispatchUpdate(10.0)
    check(subj.value == 0.02)
    dispatchUpdate(10.0)
    check(subj.value == 0.03)
    dispatchUpdate(970.0)
    check(subj.value == 1.0)

    check(isDone == true)

  test "Map animator":
    let anim = createAnimator(10.0)
    let mapped = anim.map(proc(x: float): float = -x)

    let subj = behaviorSubject(mapped.value)

    var isDone = false
    anim.start(proc() = isDone = true)

    dispatchUpdate(2.0)
    check(subj.value == -0.2)
    dispatchUpdate(2.0)
    check(subj.value == -0.4)
    dispatchUpdate(2.0)
    check(subj.value == -0.6)
    dispatchUpdate(2.0)
    check(subj.value == -0.8)
    dispatchUpdate(2.0)
    check(subj.value == -1.0)

    check(isDone == true)

  test "Animate width of a panel":
      let anim = createAnimator(10.0).map((val: float) => some(val * 100.0))
      let p = panel(width <- anim.value, height = some(10.0))

      dispatchUpdate(5.0)
      check(p.props.width == none[float]())

      anim.start()
      dispatchUpdate(5.0)
      check(p.props.width == some(50.0))

      dispatchUpdate(5.0)
      check(p.props.width == some(100.0))

  test "Animate from to":
    let animator = createAnimator(10.0, 0.0, 25.0)
    animator.start()

    let val = behaviorSubject(animator.value)

    dispatchUpdate(5.0)
    check(val.value == 12.5)

    dispatchUpdate(5.0)
    check(val.value == 25.0)

  test "Play to end then back":
    let anim = createAnimator(10.0, 0.0, 10.0)

    var isDone = false
    anim.playToEndThenBack(proc() = isDone = true)

    let val = behaviorSubject(anim.value)

    dispatchUpdate(5.0)
    check(val.value == 5.0)
    check(isDone == false)

    dispatchUpdate(5.0)
    check(val.value == 10.0)
    check(isDone == false)

    dispatchUpdate(5.0)
    check(val.value == 5.0)
    check(isDone == false)

    dispatchUpdate(5.0)
    check(val.value == 0.0)
    check(isDone == true)






