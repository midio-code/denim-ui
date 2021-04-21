import options
import strformat
import rx_nim
import ../types
import ../element
import ../element_observables
import ../../vec
import ../../rect
import ../../type_name
import ../dsl/dsl

component ScrollView(scrollProgress: Option[Vec2[float]]):
  field contentSize: Subject[Vec2[float]] = behaviorSubject(zero())
  field scrollViewSize: Subject[Vec2[float]] = behaviorSubject(zero())

implTypeName(ScrollView)

method measureOverride(self: ScrollView, availableSize: Vec2[float]): Vec2[float] =
  let props = self.scrollViewProps
  for child in self.children:
    child.measure(availableSize.withY(INF))
  var largestChild = vec2(0.0)
  for child in self.children:
    largestChild = largestChild.max(child.desiredSize.get())
  if not isNil(self.contentSize) and (isNil(self.contentSize.value) or self.contentSize.value != largestChild):
    self.contentSize.next(largestChild)
  if not isNil(self.scrollViewSize) and (isNil(self.scrollViewSize.value) or self.scrollViewSize.value != availableSize):
    self.scrollViewSize.next(availableSize)

  largestChild.min(vec2(self.props.maxWidth.get(Inf), self.props.maxHeight.get(Inf)))

method arrangeOverride(self: ScrollView, availableSize: Vec2[float]): Vec2[float] =
  let progress = self.scrollViewProps.scrollProgress.get(vec2(0.0)).clamp(vec2(0.0), vec2(1.0))
  for child in self.children:
    let childSizeOverBounds = max(vec2(0.0), child.desiredSize.get() - availableSize)
    child.arrange(rect(-progress.x * childSizeOverBounds.x, -progress.y * childSizeOverBounds.y, availableSize.x, availableSize.y))
  self.desiredSize.get()
