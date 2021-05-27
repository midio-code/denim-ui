import ./vec

type
  Circle* = ref object
    center*: Vec2[float]
    radius*: float
