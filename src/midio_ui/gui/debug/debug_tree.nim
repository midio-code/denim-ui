import sequtils, sugar, options, strformat, math, strutils
import ../types
import ../prelude
import ../drawing_primitives
import ../debug_draw
import ../update_manager

component Dock, CollapsablePanel():
  let isCollapsed = behaviorSubject(true)
  let position = behaviorSubject(vec2(0.0, 0.0))

  x <- position.extract(x)
  y <- position.extract(y)
  width <- isCollapsed.choose(100.0, 200.0)
  height <- isCollapsed.choose(50.0, 400.0)
  clipToBounds = true

  docking(DockDirection.Top):
    panel:
      onDrag(
        (delta: Vec2[float]) => position.next(position.value + delta)
      )
      rectangle(radius = (5.0,5.0,0.0,0.0), color = some("#3C3C3C"))
      dock:
        docking(DockDirection.Right):
          panel(alignment = Alignment.CenterRight):
            circle(color = "#FE5D55".parseColor, radius = 5.0, margin = thickness(5.0))
            onClicked(
              (e: Element, args: PointerArgs) => isCollapsed.next(not isCollapsed.value)
            )
        text(text = "Debug", alignment = Alignment.CenterLeft, margin = thickness(5.0))
  panel(minHeight = 5.0):
    rectangle(color = "#252526".parseColor, radius = (0.0, 0.0, 5.0, 5.0))
    panel(visibility <- isCollapsed.map((x: bool) => choose(x, Visibility.Collapsed, Visibility.Visible))):
      ...children

proc descriptor(self: Element): string =
  "some element type (todo: get actual name)"

component DebugElem(label: string, elem: Element):
  let hovering = behaviorSubject(false)

  text(text = label, color <- hovering.map((h: bool) => choose(h, "black".parseColor, "white".parseColor)))
  onHover(
    (e: Element) => debugDrawRect(elem.bounds.get().withPos(elem.actualWorldPosition)),
  )
  onHover(
    (e: Element) => hovering.next(true),
    (e: Element) => hovering.next(false),
  )

component DebugTreeImpl(tree: Element, filterText: Observable[string]):
  let elems = tree.children.map(
    (c: Element) => (c, &"{c.descriptor} - {c.id}")
  ).map(
    proc(x: tuple[c: Element, t: string]): Element =
      let toggledByUser = behaviorSubject(true) # default to open
      let visibility = toggledByUser.choose(Visibility.Visible, Visibility.Collapsed)
      let arrowRotation = toggledByUser
        .choose(PI / 2.0, 0.0)
        .animate(
          proc(a: float, b: float, t: float): seq[Transform] =
            @[rotation(lerp(a,b,t))],
          200.0
        )
      let highlightStrokeWidth = filterText.map(
        proc(text: string): float =
          choose(x.t.contains(text), 1.0, 0.0)
      ).animate(lerp, 200.0)
      dock:
        docking(DockDirection.Left):
          panel(alignment = Alignment.Top, visibility = choose(x.c.children.len() > 0, Visibility.Visible, Visibility.Hidden)):
            path(
              data = @[moveTo(0.0, 10.0), lineTo(10.0, 5.0), lineTo(0.0, 0.0), lineTo(0.0, 10.0)],
              width = 10.0,
              height = 10.0,
              fill = "red".parseColor,
              strokeWidth = 1.0,
              stroke = "black".parseColor,
              transform <- arrowRotation
            )
            onClicked(
              proc(e: Element, args: PointerArgs): void =
                toggledByUser.next(not toggledByUser.value)
            )
        stack(margin = thickness(10.0, 0.0), alignment = Alignment.Left):
          panel:
            rectangle(stroke = "red".parseColor, strokeWidth <- highlightStrokeWidth)
            debugElem(label = x.t, elem = x.c)
          panel(visibility <- visibility):
            debugTreeImpl(tree = x.c, filterText = filterText)
  )
  stack(alignment = Alignment.TopLeft):
    ...elems

component DebugTree(tree: Element):
  # var accum = 0.0
  # addUpdateListenerIfNotPresent(
  #   proc(dt: float): void =
  #     accum += dt
  #     if accum >= 4000.0:
  #       accum = 0.0
  #       content.next(DebugTreeImpl(tree = tree))
  # )

  let searchBoxText = behaviorSubject("123123")
  proc textChangedHandler(newText: string): void {.closure.} =
    searchBoxText.next(newText)

  var content = behaviorSubject[Element](debugTreeImpl(tree = tree, filterText = searchBoxText))

  let thumbPos = behaviorSubject(0.0)

  let contentSize = subject[Vec2[float]]()
  let scrollViewSize = subject[Vec2[float]]()

  let thumbHeight = contentSize.combineLatest(
    scrollViewSize,
    proc(contentSize: Vec2[float], scrollViewSize: Vec2[float]): float =
      let ratio = scrollViewSize.y / contentSize.y
      scrollViewSize.y * ratio
  )


  let scrollPos = thumbPos.combineLatest(
    contentSize.source,
    scrollViewSize.source,
    proc(val: float, content: Vec2[float], sw: Vec2[float]): Vec2[float] =
      let thumbHeight = min(1.0, (sw.y / content.y)) * sw.y
      let maxOffset = sw.y - thumbHeight
      let progress = clamp(val / maxOffset, 0.0, 1.0)
      vec2(0.0, progress)
  )

  let maxOffset = behaviorSubject(
    contentSize.source.combineLatest(
      scrollViewSize.source,
      proc(content: Vec2[float], scrollView: Vec2[float]): float =
        let thumbHeight = min(1.0, scrollView.y / content.y) * scrollView.y
        scrollView.y - thumbHeight
    )
  )

  let actualThumbPos = thumbPos.combineLatest(
    contentSize.source,
    scrollViewSize.source,
    proc(val: float, content: Vec2[float], sw: Vec2[float]): float =
      let thumbHeight = min(1.0, sw.y / content.y) * sw.y
      let maxOffset = sw.y - thumbHeight
      clamp(val, 0.0, maxOffset)
  )

  collapsablePanel:
    dock(margin = thickness(5.0)):
      #docking(DockDirection.Top):
        # textInput(
        #   text <- searchBoxText,
        #   onChange = some(textChangedHandler),
        #   color = "white"
        # )
      dock:
        docking(DockDirection.Right):
          panel(width = 8.0):
            rectangle(color = "red".parseColor)
            rectangle(
              color = "yellow".parseColor,
              height <- thumbHeight,
              alignment = Alignment.Top,
              y <- actualThumbPos
            ):
              onDrag(
                proc(diff: Vec2[float]): void =
                  thumbPos.next(clamp(thumbPos.value + diff.y, 0.0, maxOffset.value))

              )
        scrollView(
          scrollProgress <- scrollPos,
          clipToBounds = true,
          contentSize = contentSize,
          scrollViewSize = scrollViewSize
        ):
          ...content
