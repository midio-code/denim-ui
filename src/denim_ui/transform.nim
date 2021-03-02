import options
import sequtils
import sugar
import vec
import rect
import mat
import math
import strformat

type
  TransformKind* {.pure.} = enum
    Scaling, Translation, Rotation
  Transform* {.requiresInit.} = ref object
    case kind*: TransformKind
    of TransformKind.Scaling:
      scale*: Vec2[float]
    of TransformKind.Translation:
      translation*: Vec2[float]
    of TransformKind.Rotation:
      rotation*: float

proc `$`*(self: Transform): string =
  case self.kind:
    of TransformKind.Scaling:
      &"Scaling: {self.scale}"
    of TransformKind.Translation:
      &"Translation: {self.translation}"
    of TransformKind.Rotation:
      &"Rotation: {self.rotation}"

proc transformInv*(point: Vec2[float], trans: Transform): Vec2[float] =
  case trans.kind:
    of Scaling:
      result = point / trans.scale
    of Translation:
      result = point - trans.translation
    of Rotation:
      result = point.copy
      let ca = -trans.rotation.cos()
      let sa = -trans.rotation.sin()
      result.x = ca * result.x - sa * result.y
      result.y = sa * result.x + ca * result.y


proc transform*(r: Rect[float], trans: Transform): Rect[float] =
  case trans.kind:
    of Scaling:
      result = rect(
        r.pos.copy,
        r.size.copy * trans.scale,
      )
    of Translation:
      result = r.withPos(r.pos + trans.translation)
    of Rotation:
      raise newException(Exception, "Rotation is currently not supported for Rect")

proc transformInv*(point: Vec2[float], transforms: seq[Transform]): Vec2[float] =
  result = point
  for trans in transforms:
    result = result.transformInv(trans)


proc transform*(rect: Rect[float], transforms: seq[Transform]): Rect[float] =
  result = rect.copy
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

proc toMatrix*(self: Transform): Mat3 =
  case self.kind:
    of TransformKind.Scaling:
      mat.scaling(self.scale)
    of TransformKind.Translation:
      mat.translation(self.translation)
    of TransformKind.Rotation:
      mat.rotation(self.rotation)

proc toMatrix*(self: seq[Transform]): Mat3 =
  var res = mat.identity()
  for t in self:
    res = res * t.toMatrix()
  return res

proc onlyTranslations*(self: seq[Transform]): seq[Transform] =
  self.filter((x: Transform) => x.kind == TransformKind.Translation)

proc exceptTranslations*(self: seq[Transform]): seq[Transform] =
  self.filter((x: Transform) => x.kind != TransformKind.Translation)

proc onlyScaling*(self: seq[Transform]): seq[Transform] =
  self.filter((x: Transform) => x.kind == TransformKind.Scaling)

proc exceptScaling*(self: seq[Transform]): seq[Transform] =
  self.filter((x: Transform) => x.kind != TransformKind.Scaling)

proc onlyRotation*(self: seq[Transform]): seq[Transform] =
  self.filter((x: Transform) => x.kind == TransformKind.Rotation)

proc exceptRotation*(self: seq[Transform]): seq[Transform] =
  self.filter((x: Transform) => x.kind != TransformKind.Rotation)
