import element
import sugar
import rx_nim
import tables

var elementSubscriptions = initTable[Element, seq[Subscription]]()

proc subscribe*[T](self: Element, obs: Observable[T], subscriber: T -> void): void =
  elementSubscriptions.mgetorput(self, @[]).add(
    obs.subscribe(subscriber)
  )

proc subscribe*[T](self: Element, obs: ObservableCollection[T], subscriber: Change[T] -> void): void =
  elementSubscriptions.mgetorput(self, @[]).add(
    obs.subscribe(subscriber)
  )

proc subscribe*[TKey, TValue](self: Element, obs: ObservableTable[TKey, TValue], onSet: (TKey, TValue) -> void, onDeleted: (TKey, TValue) -> void): void =
  elementSubscriptions.mgetorput(self, @[]).add(
    obs.subscribe(onSet, onDeleted)
  )

proc disposeElementSubscriptions(self: Element): void =
  if self in elementSubscriptions:
    for sub in elementSubscriptions[self]:
      sub.dispose()

## Binds an element layout variable (the options are the same as the fields in ElementProps)
## to an observable.
template bindLayoutProp*[T](element: Element, prop: untyped, observable: Observable[T]): untyped =
  element.subscribe(
    observable,
    proc(newVal: T): void =
      element.props.prop = newVal
      element.invalidateLayout()
  )
