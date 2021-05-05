import number

type
  Thickness*[T: Number] = tuple[l:T,t:T,r:T,b:T]

proc thickness*(): Thickness[float] =
  (0.0,0.0,0.0,0.0)

proc thickness*[T:Number](a:T, b:T, c:T, d:T): Thickness[T] =
  (a,b,c,d)

proc thickness*[T:Number](a:T): Thickness[T] =
  (a,a,a,a)

proc thickness*[T:Number](a:T, b:T): Thickness[T] =
  (a,b,a,b)

proc left*[T:Number](self: T): Thickness[T] =
  thickness(self, 0.0, 0.0, 0.0)

proc topLeft*[T:Number](t, l: T): Thickness[T] =
  thickness(l, t, 0.0, 0.0)

template topLeft*[T:Number](tl: T): Thickness[T] =
  thickness(tl, tl, 0.0, 0.0)

proc right*[T:Number](self: T): Thickness[T] =
  thickness(0.0, 0.0, self, 0.0)

proc topRight*[T:Number](t, r: T): Thickness[T] =
  thickness(0.0, t, r, 0.0)

template topRight*[T:Number](tr: T): Thickness[T] =
  thickness(0.0, tr, tr, 0.0)

proc top*[T:Number](self: T): Thickness[T] =
  thickness(0.0, self, 0.0, 0.0)

proc bottom*[T:Number](self: T): Thickness[T] =
  thickness(0.0, 0.0, 0.0, self)

proc bottomRight*[T:Number](b, r: T): Thickness[T] =
  thickness(0.0, 0.0, r, b)

template bottomRight*[T:Number](br: T): Thickness[T] =
  thickness(0.0, 0.0, br, br)

proc bottomLeft*[T:Number](b, l: T): Thickness[T] =
  thickness(l, 0.0, 0.0, b)

template bottomLeft*[T:Number](bl: T): Thickness[T] =
  thickness(bl, 0.0, 0.0, bl)

proc horizontal*[T:Number](h: T): Thickness[T] =
  thickness(h, 0.0, h, 0.0)

proc horizontal*[T:Number](l, r: T): Thickness[T] =
  thickness(l, 0.0, r, 0.0)

proc vertical*[T:Number](v: T): Thickness[T] =
  thickness(0.0, v, 0.0, v)

proc vertical*[T:Number](t, b: T): Thickness[T] =
  thickness(0.0, t, 0.0, b)

proc left*[T:Number](self: Thickness[T]): T =
  self[0]

proc top*[T:Number](self: Thickness[T]): T =
  self[1]

proc right*[T:Number](self: Thickness[T]): T =
  self[2]

proc bottom*[T:Number](self: Thickness[T]): T =
  self[3]

proc add*[T:Number](self: Thickness[T], other: Thickness[T]): Thickness[T] =
  thickness(
    self.left + other.left,
    self.top + other.top,
    self.right + other.right,
    self.bottom + other.bottom
  )


proc lerp*(self: Thickness[float], other: Thickness[float], t: float): Thickness[float] =
  thickness(
    self[0].lerp(other[0], t),
    self[1].lerp(other[1], t),
    self[2].lerp(other[2], t),
    self[3].lerp(other[3], t),
  )
