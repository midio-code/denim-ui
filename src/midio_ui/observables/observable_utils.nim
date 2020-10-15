import ./observables

proc choose*[T](self: Observable[bool], onTrue: T, onFalse: T): Observable[T] =
  ## Maps to the first argument if the value of the obsevable is true, otherwise chooses the second argument.
  self.map(
    proc(x: bool): T =
      if x:
        onTrue
      else:
        onFalse
  )
