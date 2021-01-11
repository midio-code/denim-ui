import number
import math
import vec

type Mat3* = ref object
  data: array[9, float]

template `[]`*(a: Mat3, i, j: int): float = a.data[i * 3 + j ]
template `[]=`*(a: Mat3, i, j: int, v: float) = a.data[i * 3 + j] = v

template `[]`*(a: Mat3, i: int): float = a.data[i]
template `[]=`*(a: Mat3, i: int, v: float) = a.data[i] = v

proc newMat3(): Mat3 =
  result = Mat3(
    data: [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
  )

func identity*(): Mat3 =
  result = newMat3()
  result[0] = 1
  result[1] = 0
  result[2] = 0
  result[3] = 0
  result[4] = 1
  result[5] = 0
  result[6] = 0
  result[7] = 0
  result[8] = 1

func transpose*(a: Mat3): void =
  let res = newMat3()
  res[0] = a[0]
  res[1] = a[3]
  res[2] = a[6]
  res[3] = a[1]
  res[4] = a[4]
  res[5] = a[7]
  res[6] = a[2]
  res[7] = a[5]
  res[8] = a[8]

func `*`*(a: Mat3, b: Mat3): Mat3 =
  result = newMat3()
  result[0, 0] += b[0, 0] * a[0, 0] + b[0, 1] * a[1, 0] + b[0, 2] * a[2, 0]
  result[0, 1] += b[0, 0] * a[0, 1] + b[0, 1] * a[1, 1] + b[0, 2] * a[2, 1]
  result[0, 2] += b[0, 0] * a[0, 2] + b[0, 1] * a[1, 2] + b[0, 2] * a[2, 2]
  result[1, 0] += b[1, 0] * a[0, 0] + b[1, 1] * a[1, 0] + b[1, 2] * a[2, 0]
  result[1, 1] += b[1, 0] * a[0, 1] + b[1, 1] * a[1, 1] + b[1, 2] * a[2, 1]
  result[1, 2] += b[1, 0] * a[0, 2] + b[1, 1] * a[1, 2] + b[1, 2] * a[2, 2]
  result[2, 0] += b[2, 0] * a[0, 0] + b[2, 1] * a[1, 0] + b[2, 2] * a[2, 0]
  result[2, 1] += b[2, 0] * a[0, 1] + b[2, 1] * a[1, 1] + b[2, 2] * a[2, 1]
  result[2, 2] += b[2, 0] * a[0, 2] + b[2, 1] * a[1, 2] + b[2, 2] * a[2, 2]

func `*`*(a: Mat3, b: Vec2[float]): Vec2[float] =
  result = zero()
  result.x = a[0, 0]*b.x + a[1, 0]*b.y + a[2, 0]
  result.y = a[0, 1]*b.x + a[1, 1]*b.y + a[2, 1]

func inverse*(a: Mat3): Mat3 =
  result = newMat3()
  let determinant = (
    a[0, 0] * (a[1, 1] * a[2, 2] - a[2, 1] * a[1, 2]) -
    a[0, 1] * (a[1, 0] * a[2, 2] - a[1, 2] * a[2, 0]) +
    a[0, 2] * (a[1, 0] * a[2, 1] - a[1, 1] * a[2, 0])
  )
  let invDet = 1 / determinant
  result[0, 0] =  (a[1, 1] * a[2, 2] - a[2, 1] * a[1, 2]) * invDet
  result[1, 0] = -(a[0, 1] * a[2, 2] - a[0, 2] * a[2, 1]) * invDet
  result[2, 0] =  (a[0, 1] * a[1, 2] - a[0, 2] * a[1, 1]) * invDet
  result[0, 1] = -(a[1, 0] * a[2, 2] - a[1, 2] * a[2, 0]) * invDet
  result[1, 1] =  (a[0, 0] * a[2, 2] - a[0, 2] * a[2, 0]) * invDet
  result[2, 1] = -(a[0, 0] * a[1, 2] - a[1, 0] * a[0, 2]) * invDet
  result[0, 2] =  (a[1, 0] * a[2, 1] - a[2, 0] * a[1, 1]) * invDet
  result[1, 2] = -(a[0, 0] * a[2, 1] - a[2, 0] * a[0, 1]) * invDet
  result[2, 2] =  (a[0, 0] * a[1, 1] - a[1, 0] * a[0, 1]) * invDet

func scaling*(v: Vec2[float]): Mat3 =
  result = newMat3()
  result[0,0] = v.x
  result[1,1] = v.y
  result[2,2] = 1

func scale*(self: Mat3): Vec2[float] =
  vec2(self[0,0], self[1,1])

func translation*(v: Vec2[float]): Mat3 =
  result = identity()
  result[2,0] = v.x
  result[2,1] = v.y

func translation*(self: Mat3): Vec2[float] =
  vec2(self[2,0], self[2,1])

func rotation*(angle: float): Mat3 =
  let
    sin = sin(angle)
    cos = cos(angle)
  result[0] = cos
  result[1] = sin
  result[2] = 0

  result[3] = -sin
  result[4] = cos
  result[5] = 0

  result[6] = 0
  result[7] = 0
  result[8] = 1

