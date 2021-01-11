import ../element
import sugar
import animation
import rx_nim
import ../../number

proc addingAnimation*(elem: Element, duration: float = 800.0): Observable[float] =
  ## Returns an Observable[float] that is animated from 0.0 to 1.0 when the element gets rooted, and back to 0.0 when it gets unrooted.

  let animator = createAnimator(duration)

  var doneCallback: () -> void

  # TODO: Dispose subscription
  discard elem.observeIsRooted().subscribe(
    proc(state: RootState): void =
      if state == RootState.Rooted:
        animator.start(nil)
        elem.beforeUnroot(
          proc(e: Element, callback: () -> void) =
            doneCallback = callback
        )
      elif state == RootState.WillUnroot:
        animator.playBack(
          proc() =
            doneCallback()
        )
      else:
        animator.reset()
  )
  animator.value
