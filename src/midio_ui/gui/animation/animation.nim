import sugar
import ../../observables/observables
import ../update_manager
import ../../vec
import easings

type
  PlayDirection* = enum
    Forward, Backward
  Animator*[T] = ref object
    play*: proc(direction: PlayDirection, doneCallback: (() -> void) = nil): void
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
      time += dt
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

  Animator[float](play: play, value: state)

template createAnimator*[T](duration: float, `from`: T, to: T): Animator[T] =
  createAnimator(duration).map((x: float) => lerp(`from`, to, x))

proc start*[T](self: Animator[T], callback: (() -> void) = nil): void =
  self.play(PlayDirection.Forward, callback)

proc playBack*[T](self: Animator[T], callback: (() -> void) = nil): void =
  self.play(PlayDirection.Backward, callback)

proc playToEndThenBack*[T](self: Animator[T], callback: (() -> void) = nil): void =
  self.start(
    proc(): void =
      self.playBack(callback)
  )

proc map*[T,R](self: Animator[T], mapper: (T -> R)): Animator[R] =
  Animator[R](play: self.play, value: self.value.map(mapper))
