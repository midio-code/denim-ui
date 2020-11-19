import sugar
import options
import ../behaviors
import ../../events
import ../../vec
import ../element
import ../element_events

proc onDrag*(moved: (Vec2[float] -> void), pointerIndex: PointerIndex = PointerIndex.Primary): Behavior =
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
            if arg.pointerIndex == pointerIndex:
              element.capturePointer()
              pastPos = arg.pos
              return handled()
        )

        element.onPointerReleased(
          proc(arg: PointerArgs): EventResult =
            if arg.pointerIndex == pointerIndex:
              arg.sender.releasePointer()
        )
    )
  )
