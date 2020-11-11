import options
import vec
import rect
import math

type
  Transform* {.requiresInit.} = ref object
    scale*: Vec2[float]
    translation*: Vec2[float]
    rotation*: float

proc transform*(point: Vec2[float], transform: Option[Transform]): Vec2[float] =
  if transform.isNone:
    return point
  let t = transform.get()
  var ret = (point / t.scale) - t.translation
  # TODO: Handle rotation
  # let ca = transform.rotation.cos()
  # let sa = transform.rotation.sin()
  # ret.x = ca * ret.x - sa * ret.y
  # ret.y = sa * ret.x + ca * ret.y
  ret

proc transform*(rect: Rect[float], trans: Option[Transform]): Rect[float] =
  if trans.isNone:
    return rect
  let t = trans.get()
  Rect[float](
    pos: rect.pos + t.translation,
    size: rect.size * t.scale
  )
