import options
import vec
import rect
import math

type
  TransformKind* = enum
    Scaling, Translation, Rotation
  Transform* {.requiresInit.} = ref object
    case kind*: TransformKind
    of Scaling:
      scale*: Vec2[float]
    of Translation:
      translation*: Vec2[float]
    of Rotation:
      rotation*: float

proc transform*(point: Vec2[float], trans: Transform): Vec2[float] =
  case trans.kind:
    of Scaling:
      result = point / trans.scale
    of Translation:
      result = point - trans.translation
    of Rotation:
      result = point.copy
      let ca = trans.rotation.cos()
      let sa = trans.rotation.sin()
      result.x = ca * result.x - sa * result.y
      result.y = sa * result.x + ca * result.y

proc transform*(point: Vec2[float], transforms: seq[Transform]): Vec2[float] =
  result = point
  for trans in transforms:
    result = result.transform(trans)

proc translation*(trans: Vec2[float]): Transform =
  Transform(kind: Translation, translation: trans)

proc scale*(scale: Vec2[float]): Transform =
  Transform(kind: Scaling, scale: scale)

proc scale*(scale: float): Transform =
  scale(vec2(scale))

proc rotation*(rot: float): Transform =
  Transform(kind: Rotation, rotation: rot)
