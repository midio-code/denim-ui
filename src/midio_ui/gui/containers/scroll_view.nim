import options
import strformat
import rx_nim
import ../types
import ../element
import ../element_observables
import ../../vec
import ../../rect

type
  ScrollViewProps* = ref object
    contentSize*: Subject[Vec2[float]]
    scrollViewSize*: Subject[Vec2[float]]
    scrollProgress*: Option[Vec2[float]]

  ScrollView* = ref object of Element
    scrollViewProps*: ScrollViewProps

method measureOverride(self: ScrollView, availableSize: Vec2[float]): Vec2[float] =
  let props = self.scrollViewProps
  for child in self.children:
    child.measure(availableSize.withY(INF))
  var largestChild = vec2(0.0)
  for child in self.children:
    largestChild = largestChild.max(child.desiredSize.get())
  if not isNil(props.contentSize) and (isNil(props.contentSize.value) or props.contentSize.value != largestChild):
    props.contentSize.next(largestChild)
  if not isNil(props.scrollViewSize) and (isNil(props.scrollViewSize.value) or props.scrollViewSize.value != availableSize):
    props.scrollViewSize.next(availableSize)

  availableSize

method arrangeOverride(self: ScrollView, availableSize: Vec2[float]): Vec2[float] =
  let props = self.scrollViewProps
  let progress = props.scrollProgress.get(vec2(0.0)).clamp(vec2(0.0), vec2(1.0))
  for child in self.children:
    let childSizeOverBounds = max(vec2(0.0), child.desiredSize.get() - availableSize)
    child.arrange(rect(-progress.x * childSizeOverBounds.x, -progress.y * childSizeOverBounds.y, availableSize.x, availableSize.y))
  self.desiredSize.get()

proc createScrollView*(scrollViewProps: ScrollViewProps, props: ElementProps = ElementProps(), children: seq[Element] = @[]): ScrollView =
  result = ScrollView(
    scrollViewProps: scrollViewProps
  )
  initElement(result, props, children)
