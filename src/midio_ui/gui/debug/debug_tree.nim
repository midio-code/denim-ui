import sequtils, sugar, options, strformat
import ../prelude
import ../debug_draw
import ../update_manager

component CollapsablePanel():
  let isCollapsed = behaviorSubject(true)
  let position = behaviorSubject(vec2(0.0, 0.0))
  dock(
    x <- position.extract(x),
    y <- position.extract(y),
  ):
    docking(DockDirection.Top):
      panel:
        onDrag(
          (delta: Vec2[float]) => position.next(position.value + delta)
        )
        rectangle(radius = (5.0,5.0,0.0,0.0), color = "#3C3C3C")
        dock:
          docking(DockDirection.Right):
            panel(horizontalAlignment = HorizontalAlignment.Right, verticalAlignment = VerticalAlignment.Center):
              circle(color = "#FE5D55", radius = 5.0, margin = thickness(5.0))
              onClicked(
                (e: Element) => isCollapsed.next(not isCollapsed.value)
              )
          text(text = "Debug", horizontalAlignment = HorizontalAlignment.Left, verticalAlignment = VerticalAlignment.Center, margin = thickness(5.0))
    panel(minHeight = 5.0):
      rectangle(color = "#252526", radius = (0.0, 0.0, 5.0, 5.0))
      panel(visibility <- isCollapsed.map((x: bool) => choose(x, Visibility.Collapsed, Visibility.Visible))):
        ...children

proc descriptor(self: Element): string =
  self.layout.map(x => x.name).get("element")

component DebugElem(label: string, elem: Element):
  let hovering = behaviorSubject(false)
  panel:
    text(text = label, color <- hovering.map((h: bool) => choose(h, "black", "white")))
    onHover(
      (e: Element) => debugDrawRect(elem.bounds.get().withPos(elem.actualWorldPosition)),
    )
    onHover(
      (e: Element) => hovering.next(true),
      (e: Element) => hovering.next(false),
    )
    onClicked(
      (e: Element) => echo("ClipToBounds: ", e.boundsOfClosestElementWithClipToBounds())
    )

component DebugTreeImpl(tree: Element):
  let elems = tree.children.map(
    (c: Element) => (c, &"{c.descriptor} - {c.id}")
  ).map(
    proc(x: tuple[c: Element, t: string]): Element =
      stack(margin = thickness(10.0, 0.0), horizontalAlignment = HorizontalAlignment.Left):
        DebugElem(label = x.t, elem = x.c)
        DebugTreeImpl(tree = x.c)
  )
  stack:
    ...elems

component DebugTree(tree: Element):
  var content = behaviorSubject[Element](DebugTreeImpl(tree = tree))
  # var accum = 0.0
  # addUpdateListenerIfNotPresent(
  #   proc(dt: float): void =
  #     accum += dt
  #     if accum >= 4000.0:
  #       accum = 0.0
  #       content.next(DebugTreeImpl(tree = tree))
  # )
  CollapsablePanel:
    panel(margin = thickness(5.0)):
      ...content
