import sugar
import rx_nim
import options
import ../element
import ../types
import ../behaviors

proc onRooted*(rooted: Element -> void, unrooted: Element -> void): Behavior =
  # TODO: Remove behavior when unrooted
  var subscription: Subscription = nil
  Behavior(
    added: some(
      proc(elem: Element): void =
        subscription = elem.observeIsRooted.subscribe(
          proc(rs: RootState): void =
            case rs:
              of RootState.Unrooted:
                elem.unrooted()
              of RootState.Rooted:
                elem.rooted()
              else:
                discard
        )
    ),
    removed: some(
      proc(elem: Element): void =
        subscription.dispose()
    )
  )
