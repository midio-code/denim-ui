import options, sugar

type
  Error* = string
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
    didComplete*: bool
    subscribers*: seq[Subscriber[T]]

  CollectionSubscriber*[T] = ref object
    onAdded*: T -> void
    onRemoved*: T -> void

  ObservableCollection*[T] = ref object
    onSubscribe*: CollectionSubscriber[T] -> Subscription

  CollectionSubject*[T] = ref object
    source*: ObservableCollection[T]
    values*: seq[T]
    subscribers*: seq[CollectionSubscriber[T]]
