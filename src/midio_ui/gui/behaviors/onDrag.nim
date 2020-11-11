import sugar
import options
import ../behaviors
import ../../events
import ../../vec
import ../element
import ../element_events

proc onDrag*(moved: (Vec2[float] -> void)): Behavior =
  var pastPos = vec2(0.0, 0.0)

  Behavior(
    added: some(
      proc(element: Element): void =
        element.onPointerMoved(
          proc(arg: PointerArgs): EventResult =
            if element.hasPointerCapture():
              let diff = arg.pos.sub(pastPos)
              moved(diff)
              pastPos = arg.pos
        )
        element.onPointerPressed(
          proc(arg: PointerArgs): EventResult =
            element.capturePointer()
            pastPos = arg.pos
            handled()
        )

        element.onPointerReleased(
          proc(arg: PointerArgs): EventResult =
            arg.sender.releasePointer()
        )
    )
  )

proc onDragAbsolute*(moved: (Vec2[float] -> void)): Behavior =
  ## Like onDrag, but gives the position of the pointer instead of the
  ## vectored it has moved since the last frame.
  Behavior(
    added: some(
      proc(element: Element):void =
        element.onPointerMoved(
          proc(arg: PointerArgs): EventResult =
            if element.hasPointerCapture():
              moved(arg.pos)
        )
        element.onPointerPressed(
          proc(arg: PointerArgs): EventResult =
            element.capturePointer()
        )

        element.onPointerReleased(
          proc(arg: PointerArgs): EventResult =
            arg.sender.releasePointer()
        )
    )
  )
