import options
import sugar
import observable_collection
import ../utils

export observable_collection

type
  Error = string
  Subscriber*[T] =  ref object
    onNext*: (T) -> void
    onCompleted*: Option[() -> void]
    onError*: Option[(Error) -> void] ## \
    ## A subscriber is just a procedure that takes in the new value of the observable
  Subscription* = ref object
    dispose*: () -> void
  Observable*[T] = ref object
    onSubscribe*: (Subscriber[T]) -> Subscription ## \
    ## An observable is a procedure which when called with a subscriber as its argument
    ## creates a subscription, which causes the subscriber proc to get called whenever
    ## the value of the observable changes.
    ##
    ## Note that currently, the observable doesn't have any way of removing subscriptions.
    ## This must be added in the future as this feature becomes necessity.
  Subject*[T] = ref object
    ## A subject is an object that contains an observable source, maintains a list of subscribers
    ## and also keeps a reference or copy to the last value of the observable source.
    ## One has to use either a ``behaviorSubject`` or normal ``subject`` in order to create an observable
    ## over a value.
    source*: Observable[T]
    value*: T
    didComplete: bool
    subscribers: seq[Subscriber[T]]

proc toSubscriber[T](onNext: (T) -> void): Subscriber[T] =
  Subscriber[T](onNext: onNext, onCompleted: none[() -> void](), onError: none[(Error) -> void]())

proc subscribe*[T](self: Observable[T], subscriber: Subscriber[T]): Subscription =
  self.onSubscribe(subscriber)

proc subscribe*[T](self: Subject[T], subscriber: Subscriber[T]): Subscription =
  self.source.onSubscribe(subscriber)

proc subscribe*[T](self: Observable[T], onNext: (T) -> void): Subscription =
  self.onSubscribe(toSubscriber(onNext))

proc subscribe*[T](self: Observable[T], onNext: (T) -> void, onCompleted: () -> void): Subscription =
  self.onSubscribe(Subscriber[T](onNext: onNext, onCompleted: some(onCompleted), onError: none[(Error) -> void]()))

proc subscribe*[T](self: Observable[T], onNext: (T) -> void, onCompleted: Option[() -> void], onError: Option[(Error) -> void]): Subscription =
  self.onSubscribe(Subscriber[T](onNext: onNext, onCompleted: onCompleted, onError: onError))

proc subscribe*[T](self: Subject[T], onNext: (T) -> void): Subscription =
  self.source.subscribe(onNext)

proc notifySubscribers[T](self: Subject[T]): void =
  for subscriber in self.subscribers:
    subscriber.onNext(self.value)

proc behaviorSubject*[T](value: T): Subject[T] =
  ## Creates a ``behaviorSubject`` with the initial value of ``value``. Behavior subjects notifies
  ## as soon as a subscription is created.
  let ret = Subject[T](
    value: value,
    didComplete: false
  )
  ret.source = Observable[T](
    onSubscribe: proc(subscriber: Subscriber[T]): Subscription =
      ret.subscribers.add(subscriber)
      subscriber.onNext(ret.value)
      Subscription(
        dispose: proc(): void =
          ret.subscribers.remove(subscriber)
      )
  )
  ret

proc create*[T](onSubscribe: (Subscriber[T]) -> Subscription): Observable[T] =
  Observable[T](onSubscribe: onSubscribe)


proc create*[T](values: seq[T]): Observable[T] =
  create(
    proc(subscriber: Subscriber[T]): Subscription =
      for value in values:
        subscriber.onNext(value)
      if subscriber.onCompleted.isSome():
        subscriber.onCompleted.get()()
      Subscription(
        dispose: proc(): void = discard
      )
  )

proc then*[T](first: Observable[T], second: Observable[T]): Observable[T] =
  var currentSub: Subscription
  create(
    proc(subscriber: Subscriber[T]): Subscription =
      currentSub =  first.subscribe(
        Subscriber[T](
          onNext: subscriber.onNext,
          onCompleted: some(proc(): void =
            currentSub = second.subscribe(
              Subscriber[T](onNext: subscriber.onNext, onCompleted: subscriber.onCompleted, onError: subscriber.onError)
            )
          ),
          onError: subscriber.onError
        )
      )
      Subscription(
        dispose: proc(): void =
          currentSub.dispose()
      )
    )

proc behaviorSubject*[T](source: Observable[T]): Subject[T] =
  ## Creates a ``behaviorSubject`` from another ``observable``. This is useful
  ## when one has an observable which one would like to use as a value, exposing the latest
  ## value through the subjects ``.value`` field.
  let ret = Subject[T](
    source: source,
    didComplete: false
  )
  # NOTE: We do not care about this subscription,
  # as it is valid as long as this subject exists.
  # TODO: We might need to handle the case when the object is disposed though.
  discard ret.source.subscribe(
    proc(newVal: T): void =
      ret.value = newVal
  )
  ret

proc subject*[T](): Subject[T] =
  ## Creates a normal ``subject``, which has no value, and only notifies their subscriber
  ## the next time a new value is pushed to it.
  var ret = Subject[T]()
  ret.source = Observable[T](
    onSubscribe: proc(subscriber: Subscriber[T]): Subscription =
      ret.subscribers.add(subscriber)
      Subscription(
        dispose: proc(): void =
          ret.subscribers.remove(subscriber)
      )
  )
  ret

proc complete*[T](self: Subject[T]): void =
  self.didComplete = true
  for subscriber in self.subscribers:
    if subscriber.onCompleted.isSome():
      subscriber.onCompleted.get()()
  self.subscribers = @[]

proc next*[T](self: Subject[T], newVal: T): void =
  ## Used to push a new value to the subject, causing it to notify all its subscribers/observers.

  if self.didComplete == true:
    raise newException(Exception, "Tried to push a new value to a completed subject")
  self.value = newVal
  self.notifySubscribers()

proc next*[T](self: Subject[T], transformer: (T) -> T): void =
  ## Used to push a new value to the subject, causing it to notify all its subscribers/observers.
  ## This overload is useful if one wants to transform the current ``value`` using some mapping function.
  self.next(transformer(self.value))

converter toObservable*[T](subject: Subject[T]): Observable[T] =
  ## Gets the source observable from the subject, letts one treat a subject as it it was just a
  ## normal observable.
  subject.source

# Operators
proc map*[T,R](self: Observable[T], mapper: (T) -> R): Observable[R] =
  ## Returns a new ``Observable`` which maps values from the source ``Observable`` to a new type and value.
  result = Observable[R](
    onSubscribe: proc(subscriber: Subscriber[R]): Subscription =
      self.subscribe(
        proc(newVal: T): void =
          subscriber.onNext(mapper(newVal))
      )

  )

template extract*[T](self: Observable[T], prop: untyped): untyped =
  self.map(
    proc(val: T): auto =
      val.`prop`
  )

proc filter*[T](self: Observable[T], predicate: (T) -> bool): Observable[T] =
  Observable[T](
    onSubscribe: proc(subscriber: Subscriber[T]): Subscription =
      self.subscribe(
        proc(newVal: T): void =
          if predicate(newVal):
            subscriber.onNext(newVal),
        subscriber.onCompleted,
        subscriber.onError
      )
  )

proc combineLatest*[A,B,R](a: Observable[A], b: Observable[B], mapper: (A,B) -> R): Observable[R] =
  ## Combines two observables, pushing both their values through a mapper function that maps to a new Observable type. The new observable triggers when **either** A or B changes.
  result = Observable[R](
    onSubscribe: proc(subscriber: Subscriber[R]): Subscription =
      assert(not isNil(a))
      assert(not isNil(b))
      var lastA: Option[A]
      var lastB: Option[B]
      let sub1 = a.subscribe(
        proc(newA: A): void =
          lastA = some(newA)
          if lastB.isSome():
            subscriber.onNext(mapper(newA, lastB.get()))
      )
      let sub2 = b.subscribe(
        proc(newB: B): void =
          lastB = some(newB)
          if lastA.isSome():
            subscriber.onNext(mapper(lastA.get(), newB))
      )
      Subscription(
        dispose: proc(): void =
          sub1.dispose()
          sub2.dispose()
      )
  )

proc combineLatest*[A,B,C,R](a: Observable[A], b: Observable[B], c: Observable[C], mapper: (A,B,C) -> R): Observable[R] =
  ## Combines three observables, pushing their values through a mapper function that maps to a new Observable type. The new observable triggers when **either** A, B or C changes.
  result = Observable[R](
    onSubscribe: proc(subscriber: Subscriber[R]): Subscription =
      assert(not isNil(a))
      assert(not isNil(b))
      assert(not isNil(c))
      var lastA: Option[A]
      var lastB: Option[B]
      var lastC: Option[C]
      let sub1 = a.subscribe(
        proc(newA: A): void =
          lastA = some(newA)
          if lastB.isSome() and lastC.isSome():
            subscriber.onNext(mapper(newA, lastB.get(), lastC.get()))
      )
      let sub2 = b.subscribe(
        proc(newB: B): void =
          lastB = some(newB)
          if lastA.isSome() and lastC.isSome():
            subscriber.onNext(mapper(lastA.get(), newB, lastC.get()))
      )
      let sub3 = c.subscribe(
        proc(newC: C): void =
          lastC = some(newC)
          if lastA.isSome() and lastB.isSome():
            subscriber.onNext(mapper(lastA.get(), lastB.get(), newC))
      )
      Subscription(
        dispose: proc(): void =
          sub1.dispose()
          sub2.dispose()
          sub3.dispose()
      )
  )

proc merge*[A](a: Observable[A], b: Observable[A]): Observable[A] =
  ## Combines two observables, pushing both their values through a mapper function that maps to a new Observable type. The new observable triggers when **either** A or B changes.
  Observable[A](
    onSubscribe: proc(subscriber: Subscriber[A]): Subscription =
      let sub1 = a.subscribe(
        proc(newA: A): void =
          subscriber.onNext(newA)
      )
      let sub2 = b.subscribe(
        proc(newB: A): void =
          subscriber.onNext(newB)
      )
      Subscription(
        dispose: proc(): void =
          sub1.dispose()
          sub2.dispose()
      )
  )

proc merge*[A](observables: Observable[Observable[A]]): Observable[A] =
  ## Subscribes to each observable as they arrive, emitting their values as they are emitted
  Observable[A](
    onSubscribe: proc(subscriber: Subscriber[A]): Subscription =
      var subscriptions: seq[Subscription] = @[]
      let outerSub = observables.subscribe(
        proc(innerObs: Observable[A]): void =
          subscriptions.add innerObs.subscribe(
            proc(val: A): void =
              subscriber.onNext(val)
          )
      )
      Subscription(
        dispose: proc(): void =
          for s in subscriptions:
            s.dispose()
          outerSub.dispose()
      )
  )

proc switch*[A](observables: Observable[Observable[A]]): Observable[A] =
  ## Subscribes to each observable as they arrive after first unsubscribing from the second,
  ## emitting their values as they arrive.
  Observable[A](
    onSubscribe: proc(subscriber: Subscriber[A]): Subscription =
      var currentSubscription: Subscription
      let outerSub = observables.subscribe(
        proc(innerObs: Observable[A]): void =
          if not isNil(currentSubscription):
            currentSubscription.dispose()
          currentSubscription = innerObs.subscribe(
            proc(val: A): void =
              subscriber.onNext(val)
          )
      )
      Subscription(
        dispose: proc(): void =
          if not isNil(currentSubscription):
            currentSubscription.dispose()
          outerSub.dispose()
      )
  )

proc distinctUntilChanged*[T](self: Observable[T]): Observable[T] =
  var lastValue: Option[T] = none[T]()
  self.filter(
    proc(val: T): bool =
      if lastValue.isNone() or val != lastValue.get():
        lastValue = some(val)
        true
      else:
        false
  )


proc log*[A](observable: Observable[A], prefix: string = "Observable changed: "): Observable[A] =
  observable.map(
    proc(x: A): A =
      echo prefix, $x
      x
  )

proc loggingSubscription*[A](observable: Observable[A], prefix: string = "Observable changed: "): Subscription =
  observable.subscribe(
    proc(x: A): void =
      echo prefix, $x
  )
