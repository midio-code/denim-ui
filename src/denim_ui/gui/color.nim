import strformat
import strutils
import hashes

type
  Color* = ref object
    r*: byte
    g*: byte
    b*: byte
    a*: byte

proc `$`*(self: Color): string =
  "#" & self.r.toHex & self.g.toHex & self.b.toHex & self.a.toHex

proc newColor*(r,g,b,a: byte): Color =
  Color(
    r: r,
    g: g,
    b: b,
    a: a
  )

proc `*`*(c: Color, val: float): Color =
  let
    r = c.r
    g = c.g
    b = c.b
    a = c.a
  let rNew = byte(float(r) * val)
  let gNew = byte(float(g) * val)
  let bNew = byte(float(b) * val)
  let aNew = byte(float(a) * val)
  newColor(rNew, gNew, bNew, aNew)

proc `+`*(a,b: Color): Color =
  newColor(
    a.r + b.r,
    a.g + b.g,
    a.b + b.b,
    a.a + b.a,
  )

proc withAlpha*(c: Color, a: byte): Color =
  newColor(c.r, c.g, c.b, a)

proc hash*(self: Color): Hash =
  cast[Hash]((int(self.r) shl 24) or (int(self.g) shl 16) or (int(self.b) shl 8) or int(self.a))
