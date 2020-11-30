type
  Number* = float | int

proc lerp*[T: Number](a: T, b: T, t: float): T =
  a * (1 - t) + b * t
