import ./vec

type
  Circle* = ref object
    center*: Vec2[float]
    radius*: float

proc newCircle*(x, y, radius: float): Circle =
  Circle(
    center: vec2(x,y),
    radius: radius
  )
