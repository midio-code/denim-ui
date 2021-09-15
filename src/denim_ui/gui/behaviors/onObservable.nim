import sugar
import rx_nim
import options
import ../types
import ../behaviors

proc onObservable*[T](observable: Observable[T], handler: (item: T) -> void): Behavior =
  # TODO: Remove behavior when unrooted
  var subscription: Subscription = nil
  Behavior(
    added: some(
      proc(elem: Element): void =
        subscription = observable.subscribe(
          proc(newVal: T): void =
            handler(newVal)
        )
    ),
    removed: some(
      proc(elem: Element): void =
        subscription.dispose()
    )
  )

proc onObservable*[K,V](observable: ObservableTable[K,V], onSet: (k: K, v: V) -> void, onDel: (k: K, v: V) -> void): Behavior =
  # TODO: Remove behavior when unrooted
  var subscription: Subscription = nil
  Behavior(
    added: some(
      proc(elem: Element): void =
        subscription = observable.subscribe(onSet, onDel)
    ),
    removed: some(
      proc(elem: Element): void =
        subscription.dispose()
    )
  )
