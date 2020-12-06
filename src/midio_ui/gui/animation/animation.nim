import sugar, options, strformat
import rx_nim
import ../update_manager
import ../../vec
import ../../number
import easings

type
  PlayDirection* = enum
    Forward, Backward
  Animator*[T] = ref object
    play*: (PlayDirection, (() -> void)) -> void
    reset*: () -> void
    value*: Observable[T]

  PlayState = enum
    Stopped, PlayingForward, PlayingBackward

proc createAnimator*(duration: float): Animator[float] =
  var playState = PlayState.Stopped
  let state = subject[float]()
  var time = 0.0

  var doneCallback: () -> void = nil

  proc updater(dt: float) =
    if time < duration and playState == PlayState.PlayingForward:
      time = min(time + dt, duration)
      state.next(time / duration)
    elif time > 0.0 and playState == PlayState.PlayingBackward:
      time -= dt
      state.next(time / duration)
    if (time >= duration and playState == PlayState.PlayingForward) or (time <= 0.0 and playState == PlayState.PlayingBackward):
      playState = PlayState.Stopped
      removeUpdateListener(updater)
      if not isNil(doneCallback):
        doneCallback()

  proc play(direction: PlayDirection, dc: (() -> void) = nil) =
    doneCallback = dc

    addUpdateListenerIfNotPresent(
      updater
    )
    case direction:
      of PlayDirection.Forward:
        playState = PlayState.PlayingForward
      of PlayDirection.Backward:
        playState = PlayState.PlayingBackward

  proc reset(): void =
    time = 0.0
    playState = PlayState.Stopped

  Animator[float](play: play, value: state, reset: reset)

template createAnimator*[T](duration: float, `from`: T, to: T): Animator[T] =
  createAnimator(duration).map((x: float) => lerp(`from`, to, x))

proc start*[T](self: Animator[T], callback: (() -> void) = nil): void =
  self.play(PlayDirection.Forward, callback)

proc reset*[T](self: Animator[T]): void =
  self.reset()

proc playBack*[T](self: Animator[T], callback: (() -> void) = nil): void =
  self.play(PlayDirection.Backward, callback)

proc playToEndThenBack*[T](self: Animator[T], callback: (() -> void) = nil): void =
  self.start(
    proc(): void =
      self.playBack(callback)
  )

proc map*[T,R](self: Animator[T], mapper: (T -> R)): Animator[R] =
  Animator[R](play: self.play, value: self.value.map(mapper))


proc animate*[T,R](self: Observable[T], interpolator: (T,T,float) -> R, duration: float): Observable[R] =
  let animator = createAnimator(duration)
  var prevValue: Option[T] = none[T]()
  var currentValue: Option[T] = none[T]()
  Observable[R](
    onSubscribe: proc(subscriber: Subscriber[R]): Subscription =
      let sub1 = animator.value.subscribe(
        proc(progress: float): void =
          if prevValue.isSome() and currentValue.isSome():
            subscriber.onNext(interpolator(prevValue.get(), currentValue.get(), progress))
      )
      let sub2 = self.subscribe(
        proc(val: T): void =
          if prevValue.isNone():
            # NOTE: This makes sure the animated value is initialized correctly
            subscriber.onNext(interpolator(val, val, 0.0))
          currentValue = some(val)
          animator.reset()
          animator.start(
            proc(): void =
              prevValue = some(val)
          )
      )
      Subscription(
        dispose: proc(): void =
          sub1.dispose()
          sub2.dispose()
      )
  )
