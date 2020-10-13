import options
import sugar

# TODO: Find a better way to expose this to the rest of the code
converter toOption*[T](x: T): Option[T] = some[T](x)
converter toFloat*(x: int): float = float(x)
converter toFloatOption*(x: int): Option[float] = some(float(x))

proc find*[T](sequence: seq[T], predicate: (T) -> bool): Option[tuple[item: T, index: int]] =
  var i = 0
  for item in sequence:
    if predicate(item):
      return some((item, i))
    i += 1
  none[tuple[item: T, index: int]]()

proc remove*[T](self: var seq[T], item: T): void =
  self.delete(self.find(item))

proc deleteWhere*[T](sequence: var seq[T], predicate: (T) -> bool): void =
  let index = sequence.find(predicate)
  if index.isSome():
    sequence.delete(index.get().index)


proc isBetween*(a: float, b: float, t: float, offset: float = 0): bool =
  t >= (a + offset) and t <= (b + offset)

template choose*(cond: bool, a, b: untyped): untyped =
  if cond:
    a
  else:
    b

iterator reverse*[T](a: seq[T]): T {.inline.} =
    var i = len(a) - 1
    while i > -1:
        yield a[i]
        dec(i)
