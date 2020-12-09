import sugar, options, strutils, sequtils, tables, hashes
import ../element
import ../types
import ../drawing_primitives
import ../../thickness
import ../../vec
import ../../rect
import ../../utils
import defaults

type
  Text* = ref object of Element
    textProps*: TextProps
    lines: seq[TextLine]

  TextLine* = tuple
    content: string
    size: Vec2[float]

  FontDescriptor = ref object
    font: string
    fontSize: float # TODO: Avoid using floating point number where we need an exact match

  FontMeasureCache = TableRef[string, Vec2[float]]

proc hash(fd: FontDescriptor): Hash =
  !$(hash(fd.font) !& hash(fd.fontSize))

proc `==`(a: FontDescriptor, b: FontDescriptor): bool =
  a.font == b.font and a.fontSize == b.fontSize

proc fontDescriptor(props: TextProps): FontDescriptor =
  FontDescriptor(
    font: props.font.get(defaults.font),
    fontSize: props.fontSize.get(defaults.fontSize)
  )

let fontMeasureCaches = newTable[FontDescriptor, FontMeasureCache]()

# TODO: Remove need for this global
var measureText*: (text: string, fontSize: float, font: string, baseline: string) -> Vec2[float]

proc getOrInit[K, V](table: TableRef[K, V], key: K, init: proc(): V): V =
  if table.hasKey(key): # TODO: Avoid double loookup
    result = table[key]
  else:
    result = init()
    table[key] = result

proc measureToken(token: string, font: FontDescriptor, cache: FontMeasureCache): Vec2[float] =
  # TODO: Adde baseline to TextProps?
  cache.getOrInit(
    token,
    proc(): Vec2[float] =
      measureText(token, font.fontSize, font.font, baseline="top")
  )

iterator tokens(str: string): string =
  # TODO: Avoid copies by working with ranges
  for (token, _) in tokenize(str):
    # TODO: Split consecutive whitespace into separate tokens, so we don't cache distinct sequences of whitespace separately
    yield token

method measureOverride(self: Text, avSize: Vec2[float]): Vec2[float] =
  let font = self.textProps.fontDescriptor

  let measureCache = fontMeasureCaches.getOrInit(font, () => newTable[string, Vec2[float]]())

  var totalSize = vec2(0.0)
  var lines: seq[TextLine] = @[]

  var lineSize = vec2(0.0)
  var lastLineSize = lineSize
  var lineTokens: seq[string] = @[]

  proc flushLine() =
    var lineString = lineTokens.join()
    lines.add (content: lineString, size: lineSize)
    totalSize.x = max(totalSize.x, lineSize.x)
    totalSize.y += lineSize.y
    lastLineSize = lineSize
    lineSize = vec2(0.0)
    lineTokens = @[]

  for token in self.textProps.text.tokens():
    let tokenSize = measureToken(token, font, measureCache)

    if lineSize.x + tokenSize.x > avSize.x:
      flushLine()

    lineTokens.add(token)
    lineSize.x += tokenSize.x
    lineSize.y = max(lineSize.y, tokenSize.y)

  if lineTokens.len() > 0:
    flushLine()

  self.lines = lines

  totalSize

method render*(self: Text): Option[Primitive] =
  let props = self.textProps

  let color = props.color.get(colWhite)
  let fontSize = props.fontSize.get(defaults.fontSize)
  let font = props.font.get(defaults.font)

  var lineY = 0.0
  var children: seq[Primitive] = @[]
  for line in self.lines:
    let textInfo = TextInfo(
      text: line.content,
      font: font,
      fontSize: fontSize,
      textBaseline: "top",
      alignment: "left"
    )

    children.add Primitive(
      transform: self.props.transform,
      bounds: rect(vec2(0.0, lineY), line.size), # TODO: Horizontal alignment
      clipToBounds: false,
      shadow: none(Shadow),
      kind: PrimitiveKind.Text,
      textInfo: textInfo,
      colorInfo: ColorInfo(fill: color),
      children: @[]
    )

    lineY += line.size.y

  let container = Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    kind: PrimitiveKind.Container,
    children: children
  )
  some(container)

proc initText*(self: Text, props: TextProps): void =
  self.textProps = props

proc createText*(props: (ElementProps, TextProps), children: seq[Element] = @[]): Text =
  let (elemProps, textProps) = props
  result = Text()
  initElement(result, elemProps)
  initText(result, textProps)
