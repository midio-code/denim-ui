import sugar, options, strutils, sequtils
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
    fontSize: float

# TODO: Remove need for this global
var measureText*: (text: string, fontSize: float, font: string, baseline: string) -> Vec2[float]

proc measureToken(token: string, font: FontDescriptor): Vec2[float] =
  # TODO: Cache
  # TODO: Adde baseline to TextProps?
  measureText(token, font.fontSize, font.font, baseline="top")

iterator tokens(str: string): string =
  # TODO: Avoid copies by working with ranges
  for (token, _) in tokenize(str):
    # TODO: Split consecutive whitespace into separate tokens, so we don't cache every length of whitespace separately
    yield token

proc fontDescriptor(props: TextProps): FontDescriptor =
  FontDescriptor(
    font: props.font.get(defaults.font),
    fontSize: props.fontSize.get(12.0)
  )

method measureOverride(self: Text, avSize: Vec2[float]): Vec2[float] =
  let font = self.textProps.fontDescriptor
  
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
    let tokenSize = measureToken(token, font)

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
  let fontSize = props.fontSize.get(12.0)
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
