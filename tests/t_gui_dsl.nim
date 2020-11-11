import macros
import options
import sugar
import unittest
import testutils
import midio_ui

template notCompiles*(e: untyped): untyped =
  not compiles(e)

suite "DSL tests":
  test "Support more types for attributes":
    check:
      notCompiles:
        let testRect = rectangle_impl(("red",)) # needs a ',' to be considered a tuple with one element
  test "Test colon syntax":
    let elem = stack:
      rectangle(width= some(100.0), height= some(200.0), color= some("red"))
      rectangle(width= some(300.0), height= some(400.0), color= some("blue"))
    check(elem.children.len() == 2)
    check(elem.children[0].props.width.get() == 100.0)
    check(elem.children[0].props.height.get() == 200.0)
    check(elem.children[1].props.width.get() == 300.0)
    check(elem.children[1].props.height.get() == 400.0)
  test "Multiple layers":
    let elem = stack():
      stack():
        rectangle(width= some(100.0))
    check(elem.children.len() == 1)
    check(elem.children[0].children.len() == 1)

  test "Without referencing variables":
    let p = panel(width = some(123.0))
  test "Referencing variables":
    let foo = 123.0
    let p = panel(width = some(foo))
  test "Text with text prop":
    let t = text(text = "foobar", width = some(123.0))

  test "Panel with width as number, not option":
    let p = panel(width = 123.0)

  test "Data binding":
    let source123 = behaviorSubject(123.0)
    let sourceHeight123 = behaviorSubject(32.0)
    let p = panel(width <- source123, height <- sourceHeight123)
    check(p.props.width == 123.0)
    check(p.props.height == 32.0)
    source123.next(11111)
    check(p.props.width == 11111)
    check(p.props.height == 32.0)

  test "Data binding textInput":
    let source = behaviorSubject("foo")
    let p = textInput(width = some(123.0), text <- source)

  test "With behaviors":
    var state = 0
    let p = panel():
      panel()
      panel()
      onHover(
        proc(elem: Element): void = state += 1,
        proc(elem: Element): void = state -= 1,
      )
      panel()
      onHover(
        proc(elem: Element): void = state += 1,
        proc(elem: Element): void = state -= 1,
      )

    check(p.behaviors.len() == 2)
    check(p.children.len() == 3)

component MyComp(bar: Observable[float]):
  panel:
    rectangle(width <- bar, height = 100.0, color = "red")

component TestComp(bar: float):
  panel:
    rectangle(width = bar, height = 100.0, color = "red")

suite "Component test":
  test "Simple component test":
    let myComp = TestComp(bar = 123)
    check(myComp.children.len() == 1)
    check(myComp.children[0].children.len() == 0)
    check(myComp.children[0].props.width == 123)

  test "Component with observable arg":
    let obs = behaviorSubject(1337.0)
    let myComp = MyComp(bar = obs)
    obs.next(321.0)
    check(myComp.children[0].props.width == 321.0)

suite "DSL: Dynamic children":
  test "... syntax for children":
    let children = @[panel(), panel(), panel()]
    let foo = panel():
      ...children
    check(foo.children.len() == 3)

  test "... syntax for children 2":
    let children = @[panel(), panel(), panel()]
    let foo = panel():
      panel()
      ...children
      panel()
    check(foo.children.len() == 5)

  test "... syntax for children 3":
    let children = @[panel(), panel(), panel()]
    let foo = panel():
      ...children
      ...children
    check(foo.children.len() == 6)

  test "... syntax for children 4":
    let children = @[panel(), panel(), panel()]
    let foo = panel():
      panel()
      ...children
      panel()
      ...children
      panel()
    check(foo.children.len() == 9)

  test "... syntax for observable":
    let children = behaviorSubject(@[panel(), panel(), panel()])
    let foo = panel():
      ...children
    check(foo.children.len() == 3)

  test " ... syntax for subject with changes":
    let c1 = panel()
    let c2 = panel()
    let c3 = panel()
    let c4 = panel()
    let c5 = panel()
    let c6 = panel()

    var s1 = behaviorSubject(@[c1,c2,c3])
    var s2 = behaviorSubject(@[c4,c5,c6])

    let p = panel():
      ...s1
      ...s2

    check(p.children.len() == 6)

    s1.next(@[c1])
    check(p.children.len() == 4)

    check(p.children.contains(c1))
    check(not p.children.contains(c2))
    check(not p.children.contains(c3))
    check(p.children.contains(c4))
    check(p.children.contains(c5))
    check(p.children.contains(c6))

    s2.next(@[c4,c5,c6,c2,c3])
    check(p.children.len() == 6)
    check(p.children.contains(c1))
    check(p.children.contains(c2))
    check(p.children.contains(c3))
    check(p.children.contains(c4))
    check(p.children.contains(c5))
    check(p.children.contains(c6))

  test " ... syntax for CollectionSubject with changes":
    let c1 = panel()
    let c2 = panel()
    let c3 = panel()
    let c4 = panel()
    let c5 = panel()
    let c6 = panel()

    var s1 = observableCollection(@[c1,c2,c3])
    var s2 = observableCollection(@[c4,c5,c6])

    let p = panel():
      ...s1
      ...s2

    check(p.children.len() == 6)

    s1.remove(c2)
    s1.remove(c3)
    check(p.children.len() == 4)

    check(p.children.contains(c1))
    check(not p.children.contains(c2))
    check(not p.children.contains(c3))
    check(p.children.contains(c4))
    check(p.children.contains(c5))
    check(p.children.contains(c6))

    s2.add(c2)
    s2.add(c3)
    check(p.children.len() == 6)
    check(p.children.contains(c1))
    check(p.children.contains(c2))
    check(p.children.contains(c3))
    check(p.children.contains(c4))
    check(p.children.contains(c5))
    check(p.children.contains(c6))

suite "DSL name binding":
  test "Bind element to name":
    let p = panel():
      let foo: string = "var"
      rectangle():
        panel()
      text(text = foo, width = foo.len())

    check(p.children[1].props.width == 3)
  # test "Def proc in body":
  #   var checker = false

  #   let p = root:
  #     panel(width = 100.0, height = 100.0):
  #       panel():
  #         proc theHandler(e: Element): EventResult =
  #           checker = true
  #         onPressed(theHandler)
  #   p.invalidateLayout()
  #   performOutstandingLayoutsAndMeasures(rect(0.0, 0.0, 100.0, 100.0))

  #   discard p.dispatchPointerDown(p.pointerArgs(vec2(50.0, 50.0)))

  #   check(checker == true)
