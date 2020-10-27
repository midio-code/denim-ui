import sugar
import types
import observables


proc observableCollection*[T](values: seq[T] = @[]): CollectionSubject[T] =
  let subject = CollectionSubject[T](
    values: values
  )
  subject.source = ObservableCollection[T](
    onSubscribe: proc(subscriber: CollectionSubscriber[T]): Subscription =
      subject.subscribers.add(subscriber)
      Subscription(
        dispose: proc(): void =
          subject.subscribers.remove(subscriber)
      )
  )
  subject

proc add*[T](self: CollectionSubject[T], item: T): void =
  self.values.add(item)
  for subscriber in self.subscribers:
    subscriber.onAdded(item)

proc remove*[T](self: CollectionSubject[T], item: T): void =
  self.values.delete(self.values.find(item))
  for subscriber in self.subscribers:
    subscriber.onRemoved(item)

proc subscribe*[T](self: ObservableCollection[T], onAdded: T -> void, onRemoved: T -> void): Subscription =
  self.onSubscribe(CollectionSubscriber[T](
    onAdded: onAdded,
    onRemoved: onRemoved
  ))

proc subscribe*[T](self: CollectionSubject[T], onAdded: T -> void, onRemoved: T -> void): Subscription =
  self.source.subscribe(onAdded, onRemoved)

proc contains*[T](self: CollectionSubject[T], item: T): Observable[bool] =
  createObservable(
    proc(subscriber: Subscriber[bool]): Subscription =
      let subscription = self.subscribe(
        proc(val: T): void =
          subscriber.onNext(self.values.contains(item)),
        proc(val: T): void =
          subscriber.onNext(self.values.contains(item))
      )
      subscriber.onNext(self.values.contains(item))
      # TODO: Handle subscriptions for observable collection
      Subscription(
        dispose: subscription.dispose
      )
  )

# TODO: Implement contains for ObservableCollection
# proc contains*[T](self: ObservableCollection[T], item: T): Observable[bool] =
#   self.source.contains(item)

proc len*[T](self: CollectionSubject[T]): Observable[int] =
  createObservable(
    proc(subscriber: Subscriber[int]): Subscription =
      subscriber.onNext(self.values.len())
      let subscription = self.subscribe(
        proc(val: T): void =
          subscriber.onNext(self.values.len()),
        proc(val: T): void =
          subscriber.onNext(self.values.len())
      )
      # TODO: Handle subscriptions for observable collection
      Subscription(
        dispose: subscription.dispose
      )
  )

# TODO: Implement len for ObservableCollection
# proc len*[T](self: ObservableCollection[T]): Observable[int] =
#   self.source.len()

proc map*[T,R](self: ObservableCollection[T], mapper: (T) -> R): ObservableCollection[R] =
  ObservableCollection[T](
    onSubscribe: proc(subscriber: CollectionSubscriber[T]): Subscription =
      let subscription = self.subscribe(
        proc(newVal: T): void =
          let mapped = mapper(newVal)
          subscriber.onAdded(mapped),
        proc(removedVal: T): void =
          let mapped = mapper(removedVal)
          subscriber.onRemoved(mapped),
      )
      Subscription(
        dispose: subscription.dispose
      )
  )

template map*[T,R](self: CollectionSubject[T], mapper: (T) -> R): ObservableCollection[R] =
  self.source.map(mapper)

proc toObservable*[T](self: CollectionSubject[T]): Observable[seq[T]] =
  createObservable(
    proc(subscriber: Subscriber[seq[T]]): Subscription =
      subscriber.onNext(self.values)
      let subscription = self.subscribe(
        proc(added: T): void =
          subscriber.onNext(self.values),
        proc(removeD: T): void =
          subscriber.onNext(self.values)
      )
      Subscription(
        dispose: subscription.dispose
      )
  )

# TODO: Find a better name for this
proc observableCollection*[T](source: ObservableCollection[T]): CollectionSubject[T] =
  ## Wraps an ObservableCollection[T] in a CollectionSubject[T] so that its items are
  ## synchronously available.
  let subject = CollectionSubject[T]()
  subject.source = ObservableCollection[T](
    onSubscribe: proc(subscriber: CollectionSubscriber[T]): Subscription =
      let subscription = source.subscribe(
        proc(added: T): void =
          subject.add(added),
        proc(removed: T): void =
          subject.remove(removed)
      )

      Subscription(
        dispose: subscription.dispose
      )
  )
  subject


proc combineLatest*[A,B,R](a: ObservableCollection[A], b: ObservableCollection[B], mapper: (A,B) -> R): ObservableCollection[R] =
  ObservableCollection(
    onSubscribe: proc(subscriber: CollectionSubscriber[R]): Subscription =
      var lastAddedA: A
      var lastAddedB: B

      var lastRemovedA: A
      var lastRemovedB: B
      let subscriptionA = a.subscribe(
        proc(newA: A): void =
          lastAddedA = newA
          if not isNil(newA) and not isNil(lastAddedB):
            subscriber.onAdded(mapper(newA, lastAddedB)),
        proc(removedA: A): void =
          lastRemovedA = removedA
          if not isNil(lastRemovedB):
            subscriber.onRemoved(mapper(removedA, lastRemovedB)),
      )
      let subscriptionB = b.subscribe(
        proc(newB: B): void =
          lastAddedB = newB
          if not isNil(newB) and not isNil(lastAddedA):
            subscriber.onAdded(mapper(lastAddedA, newB)),
        proc(removedB: B): void =
          lastRemovedB = removedB
          if not isNil(lastRemovedA):
            subscriber.onRemoved(mapper(lastRemovedA, removedB)),
      )

      Subscription(
        dispose: proc(): void =
          subscriptionA.dispose()
          subscriptionB.dispose()
      )
  )
