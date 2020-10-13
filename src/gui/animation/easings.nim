import ../../utils
import math

const c1 = 1.70158;
const c2 = c1 * 1.525;
const c3 = c1 + 1;
const c4 = (2 * PI) / 3;
const c5 = (2 * PI) / 4.5;

proc easeInQuad*(x: float): float = x * x

proc easeOutQuad*(x: float): float = 1 - (1 - x) * (1 - x)

proc easeInOutQuad*(x: float): float =
  if x < 0.5:
    2.0 * x * x
  else:
    1.0 - pow(-2.0 * x + 2.0, 2.0) / 2.0

proc easeInCubic*(x: float): float = x * x * x

proc easeOutCubic*(x: float): float = 1 - pow(1 - x, 3)

proc easeInOutCubic*(x: float): float =
  if x < 0.5:
    4 * x * x * x
  else:
    1 - pow(-2 * x + 2, 3) / 2

proc easeInQuart*(x: float): float = x * x * x * x

proc easeOutQuart*(x: float): float = 1 - pow(1 - x, 4)

proc easeInOutQuart*(x: float): float =
  if x < 0.5:
    8 * x * x * x * x
  else:
    1 - pow(-2 * x + 2, 4) / 2

proc easeInQuint*(x: float): float = x * x * x * x * x

proc easeOutQuint*(x: float): float = 1 - pow(1 - x, 5)

proc easeInOutQuint*(x: float): float =
  if x < 0.5:
    16 * x * x * x * x * x
  else:
    1 - pow(-2 * x + 2, 5) / 2

proc easeInSine*(x: float): float = 1 - cos((x * PI) / 2)

proc easeOutSine*(x: float): float = sin((x * PI) / 2)

proc easeInOutSine*(x: float): float = -(cos(PI * x) - 1) / 2

proc easeInCirc*(x: float): float = 1 - sqrt(1 - pow(x, 2))

proc easeOutCirc*(x: float): float = sqrt(1 - pow(x - 1, 2))

proc easeInOutCirc*(x: float): float =
  if x < 0.5:
    (1 - sqrt(1 - pow(2 * x, 2))) / 2
  else:
    (sqrt(1 - pow(-2 * x + 2, 2)) + 1) / 2

proc easeInBack*(x: float): float = c3 * x * x * x - c1 * x * x

proc easeOutBack*(x: float): float = 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)

proc easeInOutBack*(x: float): float =
  if x < 0.5:
    (pow(2 * x, 2) * ((c2 + 1) * 2 * x - c2)) / 2
  else:
    (pow(2 * x - 2, 2) * ((c2 + 1) * (x * 2 - 2) + c2) + 2) / 2

proc easeInElastic*(x: float): float =
  if x == 0:
    0.0
  elif x == 1.0:
    1.0
  else:
      -pow(2, 10 * x - 10) * sin((x * 10 - 10.75) * c4)

proc easeOutElastic*(x: float): float =
  if x == 0:
    0.0
  elif x == 1.0:
    1.0
  else:
    pow(2, -10 * x) * sin((x * 10 - 0.75) * c4) + 1

proc easeInOutElastic*(x: float): float =
  if x == 0:
    0.0
  elif x == 1.0:
    1.0
  elif x < 0.5:
    -(pow(2, 20 * x - 10) * sin((20 * x - 11.125) * c5)) / 2
  else:
    (pow(2, -20 * x + 10) * sin((20 * x - 11.125) * c5)) / 2 + 1
