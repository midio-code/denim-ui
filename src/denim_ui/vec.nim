import strformat
import number
import thickness
import math

type
  Vec2*[T:Number] = ref object
    x*: T
    y*: T

proc `$`*[T:Number](self: Vec2[T]): string =
  &"vec({self.x}, {self.y})"

proc copy*[T:Number](self: Vec2[T]): Vec2[T] =
  Vec2[T](x: self.x, y: self.y)

proc vec2*[T:Number](x: T, y: T): Vec2[T] =
  Vec2[T](x: x, y: y)

proc vec2*[T:Number](xy: T): Vec2[T] =
  Vec2[T](x: xy, y: xy)

proc zero*(): Vec2[float] =
  vec2(0.0, 0.0)

proc `-`*[T: Number](self: Vec2[T]): Vec2[T] =
  vec2(-self.x, -self.y)

proc infinity*[T:Number](): Vec2[T] =
  Vec2[T](fcInf, fcInf)

proc withX*[T:Number](self: Vec2[T], x: Number): Vec2[T] =
  vec2(x, self.y)

proc withY*[T:Number](self: Vec2[T], y: Number): Vec2[T] =
  vec2(self.x, y)

proc lerp*[T:Number](self: Vec2[T], other: Vec2[T], t: float): Vec2[T] =
  vec2(lerp(self.x, other.x, t), lerp(self.y, other.y, t))

proc add*[T:Number](self: Vec2[T], other: Vec2[T]): Vec2[T] =
  vec2(self.x + other.x, self.y + other.y)

template `+`*[T:Number](self: Vec2[T], other: Vec2[T]): Vec2[T] =
  self.add(other)

proc addX*[T:Number](self: Vec2[T], other: T): Vec2[T] =
  vec2(self.x + other, self.y)

proc addY*[T:Number](self: Vec2[T], other: T): Vec2[T] =
   vec2(self.x, self.y + other)

proc directionTo*[T:Number](self: Vec2[T], other: Vec2[T]): Vec2[T] =
  other.sub(self).normalized()

proc sub*[T:Number](self: Vec2[T], other: Vec2[T]): Vec2[T] =
  vec2(self.x - other.x, self.y - other.y)

template `-`*[T:Number](self: Vec2[T], other: Vec2[T]): Vec2[T] =
  self.sub(other)

proc `-`*[T:Number](self: Vec2[T], other: T): Vec2[T] =
  vec2(self.x - other, self.y - other)

proc angle*[T:Number](self: Vec2[T]): T =
  arctan2(self.y, self.x)

proc normalized*[T:Number](self: Vec2[T]): Vec2[T] =
  let len = self.length()
  vec2(self.x / len, self.y / len)

proc divide*[T:Number](self: Vec2[T], val: Number): Vec2[T] =
  vec2(self.x / val, self.y / val)

proc divide*[T:Number](self: T, val: Vec2[T]): Vec2[T] =
  vec2(self / val.x, self / val.y)

proc divide*[T:Number](self: Vec2[T], other: Vec2[T]): Vec2[T] =
  vec2(self.x / other.x, self.y / other.y)

template `/`*[T:Number](self: Vec2[T], val: Number): Vec2[T] =
  self.divide(val)

template `/`*[T:Number](self: Number, val: Vec2[T]): Vec2[T] =
  self.divide(val)

template `/`*[T:Number](self: Vec2[T], other: Vec2[T]): Vec2[T] =
  self.divide(other)

proc mul*[T:Number](self: Vec2[T], other: T): Vec2[T] =
  vec2(self.x * other, self.y * other)

proc mul*[T:Number](self: Vec2[T], other: Vec2[T]): Vec2[T] =
  vec2(self.x * other.x, self.y * other.y)

proc mul*[T:Number](self: Vec2[T], otherX: T, otherY: T): Vec2[T] =
  vec2(self.x * otherX, self.y * otherY)

template `*`*[T:Number](self: Vec2[T], other: Vec2[T]): Vec2[T] =
  self.mul(other)

template `*`*[T:Number](self: Vec2[T], other: T): Vec2[T] =
  self.mul(other)

proc rotate*[T:Number](self: Vec2[T], rad: Number): Vec2[T] =
  let cs = cos(rad)
  let sn = sin(rad)
  let px = float(self.x) * cs - float(self.y) * sn
  let py = float(self.x) * sn + float(self.y) * cs
  vec2(T(px), T(py))


proc max*[T:Number](self: Vec2[T], other: Vec2[T]): Vec2[T] =
  vec2(max(other.x, self.x), max(other.y, self.y))

proc min*[T:Number](self: Vec2[T], other: Vec2[T]): Vec2[T] =
  vec2(min(other.x, self.x), min(other.y, self.y))

proc clamp*[T:Number](self: Vec2[T], a: Vec2[T], b: Vec2[T]): Vec2[T] =
  self.min(b).max(a)

proc abs*[T:Number](self: Vec2[T]): Vec2[T] =
  vec2(abs(self.x), abs(self.y))

proc heightVec*[T:Number](self: Vec2[T]): Vec2[T] =
  vec2(0, self.y)


proc widthVec*[T:Number](self: Vec2[T]): Vec2 =
  vec2(self.x, 0)


proc inflate*[T:Number](self: Vec2[T], thickness: Thickness[T]): Vec2[T] =
  vec2(
    self.x + thickness.left() + thickness.right(),
    self.y + thickness.top() + thickness.bottom()
  )

proc deflate*[T:Number](self: Vec2[T], thickness: Thickness[T]): Vec2[T] =
  vec2(
    self.x - thickness.left() - thickness.right(),
    self.y - thickness.top() - thickness.bottom()
  )

proc `==`*[T:Number](self: Vec2[T], other: Vec2[T]): bool =
  if isNil(self) or isNil(other):
    return false
  self.x == other.x and self.y == other.y

proc nonNegative*[T:Number](self: Vec2[T]): Vec2[T] =
  vec2(max(self.x, 0.0), max(self.y, 0.0))


proc constrain*[T:Number](self: Vec2[T], constraint: Vec2[T]): Vec2[T] =
  vec2(
    min(self.x, constraint.x),
    min(self.y, constraint.y)
  )


proc length*[T:Number](self: Vec2[T]): T =
  sqrt(self.x * self.x + self.y * self.y)


proc distanceTo*[T:Number](self:Vec2[T], other: Vec2[T]): T =
  other.sub(self).length()

proc neg*[T:Number](self: Vec2[T]): Vec2[T] =
  vec2(-self.x, -self.y)
