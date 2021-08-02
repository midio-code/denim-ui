import options
import sugar
import gui/types
import strformat
import colors as stdColor
import gui/color as guiColor

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


proc isBetween*(t: float, a: float, b: float, offset: float = 0): bool =
  t >= (a + offset) and t <= (b + offset)

template choose*(cond: bool, a, b: untyped): untyped =
  if cond:
    a
  else:
    b


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

proc lerp*(a: guiColor.Color, b: guiColor.Color, t: float): guiColor.Color =
  (a * (1.0 - t)) + (b * t)

proc createInterpolator*[T](easing: float -> float, lerper: (T,T,float) -> T): ((T,T,float) -> T) =
  result = proc(a, b: T, t: float): T =
    lerper(a, b, easing(t))

converter fromStdColorColor*(color: stdColor.Color): guiColor.Color =
  let (r,g,b) = stdColor.extractRGB(color)
  newColor(byte(r), byte(g), byte(b), 0xff)

converter fromStdColorOptColor*(color: stdColor.Color): Option[guiColor.Color] =
  some(fromStdColorColor(color))

converter fromStdColorColorToStyle*(color: stdColor.Color): ColorStyle =
  newSolidColor(fromStdColorColor(color))

converter fromStdColorColorToStyleOpt*(color: stdColor.Color): Option[ColorStyle] =
  some(newSolidColor(fromStdColorColor(color)))

converter fromStdColorColorOpt*(color: Option[stdColor.Color]): Option[ColorStyle] =
  if color.isSome:
    some(newSolidColor(fromStdColorColor(color.get)))
  else:
    none[ColorStyle]()

converter toSolidColor*(optColor: Option[guiColor.Color]): Option[ColorStyle] =
  if optColor.isSome:
    some(newSolidColor(optColor.get))
  else:
    none[ColorStyle]()

proc parseColor*(colString: string): guiColor.Color =
  if colString.len != 7 or colString[0] != '#':
    raise newException(Exception, &"Color string is longer than expected ({colString}) (only the form '#rrggbb' is currently supported (not alpha, even though alpha is supported by the color type))")
  fromStdColorColor(stdColor.parseColor(colString))
