import element
import rx_nim

template bindProp*[T](prop: typed, observable: Observable[T]): untyped =
  # TODO: Handle disposing of subscription
  discard observable.subscribe(
    proc(newVal: T): void =
      prop = newVal
  )

template bindCollection*[T](prop: seq[T], collection: ObservableCollection[T]): untyped =
  collection.subscribe(
    proc(newVal: T): void =
      prop.add(newVal),
    proc(removedVal: T): void =
      prop.delete(prop.find(removedVal))
  )

## Binds an element layout variable (the options are the same as the fields in ElemProps)
## to an observable.
template bindLayoutProp*[T](element: Element, prop: untyped, observable: Observable[T]): untyped =
  # TODO: Handle disposing of subscription
  discard observable.subscribe(
    proc(newVal: T): void =
      element.props.prop = newVal
      element.invalidateLayout()
  )
