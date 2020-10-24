import sugar
import observables

type
  AddedSubscriber*[T] = (T) -> void
  RemovedSubscriber*[T] = (T) -> void
  ObservableCollection*[T] = (AddedSubscriber[T], RemovedSubscriber[T]) -> void

  CollectionSubject*[T] = ref object
    source*: ObservableCollection[T]
    values*: seq[T]
    addedSubscribers: seq[AddedSubscriber[T]]
    removedSubscribers: seq[RemovedSubscriber[T]]

proc observableCollection*[T](values: seq[T] = @[]): CollectionSubject[T] =
  let subject = CollectionSubject[T](
    values: values,
  )
  subject.source =
    proc(addedSubscriber: AddedSubscriber[T], removedSubscriber: RemovedSubscriber[T]): void =
      subject.addedSubscribers.add(addedSubscriber)
      subject.removedSubscribers.add(removedSubscriber)
      # TODO: Create an observable collection behavior subject
      # for item in subject.values:
      #   addedSubscriber(item)
  subject

proc add*[T](self: CollectionSubject[T], item: T): void =
  self.values.add(item)
  for subscriber in self.addedSubscribers:
    subscriber(item)

proc remove*[T](self: CollectionSubject[T], item: T): void =
  self.values.delete(self.values.find(item))
  for subscriber in self.removedSubscribers:
    subscriber(item)

proc contains*[T](self: CollectionSubject[T], item: T): Observable[bool] =
  createObservable(
    proc(subscriber: Subscriber[bool]): Subscription =
      if self.values.contains(item):
        subscriber.onNext(true)
      self.source(
        proc(val: T): void =
          if val == item:
            subscriber.onNext(true),
        proc(val: T): void =
          if val == item:
            subscriber.onNext(false)
      )
      # TODO: Handle subscriptions for observable collection
      Subscription(
        dispose: proc(): void = discard
      )
  )

proc len*[T](self: CollectionSubject[T]): Observable[int] =
  createObservable(
    proc(subscriber: Subscriber[int]): Subscription =
      subscriber.onNext(self.values.len())
      self.source(
        proc(val: T): void =
          subscriber.onNext(self.values.len()),
        proc(val: T): void =
          subscriber.onNext(self.values.len())
      )
      # TODO: Handle subscriptions for observable collection
      Subscription(
        dispose: proc(): void = discard
      )
  )

proc map*[T,R](self: ObservableCollection[T], mapper: (T) -> R): ObservableCollection[R] =
  # TODO: Have a separate object to keep subscribers so that we don't need a subject here
  var hasSubscribedToSource = false
  let subject = CollectionSubject[R]()
  result = proc(added: AddedSubscriber[R], removed: RemovedSubscriber[R]): void =
    if not hasSubscribedToSource:
      hasSubscribedToSource = true
      self(
        proc(newVal: T): void =
          let mapped = mapper(newVal)
          for sub in subject.addedSubscribers:
            sub(mapped),
        proc(removedVal: T): void =
          let mapped = mapper(removedVal)
          for sub in subject.removedSubscribers:
            sub(mapped),
      )
    subject.addedSubscribers.add(added)
    subject.removedSubscribers.add(removed)

template map*[T,R](self: CollectionSubject[T], mapper: (T) -> R): ObservableCollection[R] =
  self.source.map(mapper)

proc toObservable*[T](self: ObservableCollection[T]): Observable[seq[T]] =
  createObservable(
    proc(subscriber: Subscriber[T]): Subscription =
      self.source(
        proc(added: T): void =
          subscriber.onNext(self.values),
        proc(removeD: T): void =
          subscriber.onNext(self.values)
      )
      Subscription(
        # TODO: Make subscriptions for observable collection
        dispose: proc(): void = discard
      )
  )

proc observableCollection*[T](source: ObservableCollection[T]): CollectionSubject[T] =
  let subject = CollectionSubject[T](
    source: source,
  )
  subject.source(
    proc(newVal: T): void =
      subject.values.add(newVal),
    proc(removedVal: T): void =
      subject.values.delete(subject.values.find(removedVal))
  )
  subject


proc combineLatest*[A,B,R](a: ObservableCollection[A], b: ObservableCollection[B], mapper: (A,B) -> R): ObservableCollection[R] =
  result = proc(added: AddedSubscriber[R], removed: RemovedSubscriber[R]): void =
    var lastAddedA: A
    var lastAddedB: B

    var lastRemovedA: A
    var lastRemovedB: B
    a(
      proc(newA: A): void =
        lastAddedA = newA
        if not isNil(newA) and not isNil(lastAddedB):
          added(mapper(newA, lastAddedB)),
      proc(removedA: A): void =
        lastRemovedA = removedA
        if not isNil(lastRemovedB):
          removed(mapper(removedA, lastRemovedB)),
    )
    b(
      proc(newB: B): void =
        lastAddedB = newB
        if not isNil(newB) and not isNil(lastAddedA):
          added(mapper(lastAddedA, newB)),
      proc(removedB: B): void =
        lastRemovedB = removedB
        if not isNil(lastRemovedA):
          removed(mapper(lastRemovedA, removedB)),
    )
