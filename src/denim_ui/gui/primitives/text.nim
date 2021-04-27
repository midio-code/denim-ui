import sugar, options, strutils, sequtils, tables, hashes
import ../element
import ../types
import ../drawing_primitives
import ../../thickness
import ../../vec
import ../../rect
import ../../utils
import ../../events
import ../../type_name
import defaults


# TODO: Remove need for this global
var measureText*: (text: string, fontSize: float, font: string, baseline: string) -> Vec2[float]

proc getOrInit[K, V](table: TableRef[K, V], key: K, init: proc(): V): V =
  if table.hasKey(key): # TODO: Avoid double loookup
    result = table[key]
  else:
    result = init()
    table[key] = result

iterator tokens(str: string): string =
  # TODO: Avoid copies by working with ranges
  for (token, isWhitespace) in tokenize(str):
    if isWhitespace:
      # TODO: Optimize this
      for character in token.replace("\r\n", "\n"):
        yield $character
    else:
      yield token

method measureOverride(self: Text, avSize: Vec2[float]): Vec2[float] =
  let props = self.textProps

  let font = props.font.get(defaults.font)
  let fontSize = props.fontSize.get(defaults.fontSize)

  var totalSize = vec2(0.0)
  var lines: seq[TextLine] = @[]

  var lineSize = vec2(0.0)
  var lastLineSize = lineSize
  var lineTokens: seq[string] = @[]

  proc flushLine() =
    var lineString = lineTokens.join()
    let actualLineSize = vec2(
      lineSize.x,
      max(lineSize.y, fontSize)
    )
    lines.add (content: lineString, size: actualLineSize)
    totalSize.x = max(totalSize.x, lineSize.x)
    totalSize.y += lineSize.y
    lastLineSize = lineSize
    lineSize = vec2(0.0)
    lineTokens = @[]

  proc insertToken(token: string, tokenSize: Vec2[float]) =
    lineTokens.add(token)
    lineSize.x += tokenSize.x
    lineSize.y = max(lineSize.y, tokenSize.y)

  for token in self.textProps.text.tokens():
    let tokenSize = measureText(token, fontSize, font, baseline = "top")

    if token == "\n":
      flushLine()
    else:
      let shouldWrap =
        props.wordWrap and
        lineTokens.len() > 0 and
        lineSize.x + tokenSize.x > avSize.x and
        not token.isEmptyOrWhitespace

      if shouldWrap:
        flushLine()

      # TODO: We currently include trailing whitespace past the wrapping point here, which will break layout for center/right alignment
      insertToken(token, tokenSize)

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
      children: @[],
      opacity: self.props.opacity
    )

    lineY += line.size.y

  let container = Primitive(
    transform: self.props.transform,
    bounds: self.bounds.get(),
    clipToBounds: self.props.clipToBounds.get(false),
    kind: PrimitiveKind.Container,
    children: children,
    opacity: self.props.opacity
  )
  some(container)


var invalidateTextEmitter = emitter[InvalidateTextArgs]()

proc invalidateAllText*(): void =
  invalidateTextEmitter.emit(InvalidateTextArgs())

method onRooted*(self: Text) =
  invalidateTextEmitter.add(self.onInvalidate)

method onUnrooted*(self: Text) =
  invalidateTextEmitter.remove(self.onInvalidate)

proc initText*(self: Text, props: TextProps): void =
  self.textProps = props

proc createText*(props: (ElementProps, TextProps), children: seq[Element] = @[]): Text =
  let (elemProps, textProps) = props
  let ret = Text()
  ret.onInvalidate =
    proc(args: InvalidateTextArgs) =
      ret.invalidateLayout()
  initElement(ret, elemProps)
  initText(ret, textProps)
  ret
