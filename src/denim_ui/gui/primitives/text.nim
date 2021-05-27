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
from colors import colWhite


# TODO: Remove need for this global
var measureText*: (text: string, fontSize: float, fontFamily: string, fontWeight: int, baseline: string) -> Vec2[float]

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

proc measureMultilineText*(text: string, fontFamily: string, fontSize: float, fontWeight: int, wordWrap: bool, avSize: Vec2[float]): (seq[TextLine], Vec2[float]) =
  if text.len == 0:
    return (
      @[],
      vec2(
        0.0,
        fontSize
      )
    )
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
    totalSize.y += actualLineSize.y
    lastLineSize = actualLineSize
    lineSize = vec2(0.0)
    lineTokens = @[]

  proc insertToken(token: string, tokenSize: Vec2[float]) =
    lineTokens.add(token)
    lineSize.x += tokenSize.x
    lineSize.y = max(lineSize.y, tokenSize.y)

  for token in text.tokens():
    let tokenSize = measureText(token, fontSize, fontFamily, fontWeight, baseline = "top")

    if token == "\n":
      flushLine()
    else:
      let shouldWrap =
        wordWrap and
        lineTokens.len() > 0 and
        lineSize.x + tokenSize.x > avSize.x and
        not token.isEmptyOrWhitespace

      if shouldWrap:
        flushLine()

      # TODO: We currently include trailing whitespace past the wrapping point here, which will break layout for center/right alignment
      insertToken(token, tokenSize)

  if lineTokens.len() > 0 or text[text.len - 1] == '\n':
    flushLine()

  (lines, totalSize)

method measureOverride(self: Text, avSize: Vec2[float]): Vec2[float] =
  let props = self.textProps
  let (lines, totalSize) = measureMultilineText(
    self.textProps.text,
    props.fontFamily.get(defaults.fontFamily),
    props.fontSize.get(defaults.fontSize),
    props.fontWeight.get(defaults.fontWeight),
    props.wordWrap,
    avSize
  )
  self.lines = lines
  totalSize

method render*(self: Text): Option[Primitive] =
  let props = self.textProps

  let color = props.color.get(colWhite)
  let fontSize = props.fontSize.get(defaults.fontSize)
  let fontFamily = props.fontFamily.get(defaults.fontFamily)
  let fontWeight = props.fontWeight.get(defaults.fontWeight)
  let fontStyle = props.fontStyle.get(defaults.fontStyle)

  var lineY = 0.0
  var children: seq[Primitive] = @[]
  for line in self.lines:
    let textInfo = TextInfo(
      text: line.content,
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
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
