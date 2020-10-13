import number
import thickness
import vec

type
  Rect*[T:Number] = object
    pos*: Vec2[T]
    size*: Vec2[T]


proc rect*[T:Number](pos: Vec2[T], size: Vec2[T]): Rect[T] =
  Rect[T](pos: pos, size: size)

proc rect*[T:Number](l: T, t: T, r: T, b: T): Rect[T] =
  assert(l <= r)
  assert(t <= b)
  rect(vec2(l, t), vec2(r - l, b - t))

proc rect*[T:Number](val: T): Rect[T] =
  rect(val, val, val, val)

proc rectFromPoints*[T:Number](p1: Vec2[T], p2: Vec2[T]): Rect[T] =
  rect(min(p1.x, p2.x), min(p1.y, p2.y), max(p1.x, p2.x), max(p1.y, p2.y))

proc translate*[T:Number](self: Rect[T], trans: Vec2[T]): Rect[T] =
  rect(self.pos.add(trans), self.size)

proc x*[T:Number](self: Rect[T]): Number =
  result = self.pos.x

proc y*[T:Number](self: Rect[T]): Number =
  result = self.pos.y


proc width*[T:Number](self: Rect[T]): T =
  result = self.size.x

proc height*[T:Number](self: Rect[T]): T =
  result = self.size.y


proc left*[T:Number](self: Rect[T]): T =
  result = self.x


proc top*[T:Number](self: Rect[T]): T =
  result = self.y


proc right*[T:Number](self: Rect[T]): T =
  result = self.x + self.width


proc bottom*[T:Number](self: Rect[T]): T =
  result = self.y + self.height

proc center*(self: Rect[float]): Vec2[float] =
  vec2(
    lerp(self.left(), self.right(), 0.5),
    lerp(self.top(), self.bottom(), 0.5)
  )

proc `[]`*[T:Number](self: Rect[T], i: range[0..3]): T =
  case i:
    of 0: self.x()
    of 1: self.y()
    of 2: self.width()
    of 3: self.height()

type
  SubdivisionV[T:Number] = object
    top: Rect[T]
    bottom: Rect[T]
  SubdivisionH[T:Number] = object
    left: Rect[T]
    right: Rect[T]

proc subdivideVertical*[T:Number](self: Rect[T], atY: Number): SubdivisionV =
  let top = Rect(self.pos, self.size.withY(atY))
  let bottom = Rect(self.pos.add(top.size.heightVec), self.size.withY(self.size.y - top.size.y))
  result = SubdivisionV(top, bottom)

proc subdivideHorizontal*[T:Number](self: Rect[T], atX: Number): SubdivisionH =
  let left = Rect(self.pos, self.size.withX(atX))
  let right = Rect(self.pos.add(left.size.widthVec), self.size.withX(self.size.x - left.size.x))
  result = SubdivisionH(left, right)

proc inflate*[T:Number](self: Rect[T], thickness: Thickness): Rect =
  let newPos = self.pos.sub(thickness.left(), thickness.top())
  let newSize = self.size.add(thickness.right(), thickness.bottom())
  rect(newPos, newSize)

proc deflate*[T:Number](self: Rect[T], thickness: Thickness): Rect =
  let newPos = self.pos.add(thickness.left(), thickness.top())
  let newSize = self.size.sub(thickness.right(), thickness.bottom())
  rect(newPos, newSize)

proc withX*[T:Number](self: Rect[T], x: T): Rect[T] =
  result = rect(self.pos.withX(x), self.size)

proc withY*[T:Number](self: Rect[T], y: T): Rect[T] =
  result = rect(self.pos.withY(y), self.size)

proc withPos*[T:Number](self: Rect[T], pos: Vec2[T]): Rect[T] =
  rect(pos, self.size)

proc withSize*[T:Number](self: Rect[T], size: Vec2[T]): Rect[T] =
  rect(self.pos, size)

proc withWidth*[T:Number](self: Rect[T], w: Number): Rect[T] =
  result = rect(self.pos, self.size.withX(w))


proc withHeight*[T:Number](self: Rect[T], h: Number): Rect[T] =
  result = rect(self.pos, self.size.withY(h))


proc equals*[T:Number](self: Rect[T], other: Rect[T]): bool =
  result = other.size.equals(self.size) and other.pos.equals(self.pos)

proc intersects*[T:Number](a: Rect[T], b: Rect[T]): bool =
  a.left <= b.right and a.right >= b.left and a.top <= b.bottom and a.bottom >= b.top

proc `==`[T:Number](self: Rect[T], other: Rect[T]): bool =
  other.size.equals(self.size) and other.pos.equals(self.pos)
