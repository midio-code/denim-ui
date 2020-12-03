import sugar
import tables
import options
import sequtils
import itertools
import ../element
import ../../guid
import ../../vec
import ../../thickness
import ../../rect

type
  Grid* = ref object of Element
    gridProps*: GridProps

  GridProps* = ref object
    rows*: seq[GridSection]
    cols*: seq[GridSection]

  GridSection* = ref object
    metric*: GridMetric
    extent*: float
    actualExtent: float # Computed during measure phase and cached here

  GridMetric* {.pure.} = enum Points, Proportion

  AxisMetrics = object
    staticExtent: float
    sumOfProportions: float

proc points*(extent: float): GridSection =
  GridSection(
    extent: extent,
    actualExtent: extent,
    metric: GridMetric.Points
  )

proc proportion*(extent: float): GridSection =
  GridSection(
    extent: extent,
    actualExtent: 0.0,
    metric: GridMetric.Proportion
  )

proc computeAxisMetrics(sections: openArray[GridSection]): AxisMetrics =
  var staticExtent = 0.0
  var sumOfProportions = 0.0
  for section in sections:
    if section.metric == GridMetric.Points:
      staticExtent += section.extent
    elif section.metric == GridMetric.Proportion:
      sumOfProportions += section.extent
  AxisMetrics(
    staticExtent: staticExtent,
    sumOfProportions: sumOfProportions
  )

proc computeRemainingSpace(axisMetrics: AxisMetrics, available: float): float =
  if available == INF: 0.0
  else: max(0.0, available - axisMetrics.staticExtent)

proc computeActualExtent(section: GridSection, axisMetrics: AxisMetrics, available: float): float =
  case section.metric:
    of GridMetric.Points: section.extent
    of GridMetric.Proportion:
      if axisMetrics.sumOfProportions == 0.0:
        0.0
      else:
        let remaining = computeRemainingSpace(axisMetrics, available) #TODO: Can be precomputed
        remaining * section.extent / axisMetrics.sumOfProportions

method measureOverride(self: Grid, available: Vec2[float]): Vec2[float] =
  let props = self.gridProps

  let metricsX = computeAxisMetrics(props.cols)
  let metricsY = computeAxisMetrics(props.rows)

  let remainingX = computeRemainingSpace(metricsX, available.x)
  let remainingY = computeRemainingSpace(metricsY, available.y)

  let maxColIndex = props.cols.len() - 1
  let maxRowIndex = props.rows.len() - 1
  var atColIndex = 0
  var atRowIndex = 0

  for child in self.children:
    var colSpec = props.cols[atColIndex]
    var rowSpec = props.rows[atRowIndex]
    
    let actualExtent = vec2(
      computeActualExtent(colSpec, metricsX, available.x),
      computeActualExtent(rowSpec, metricsY, available.y)
    )

    colSpec.actualExtent = actualExtent.x
    rowSpec.actualExtent = actualExtent.y

    child.measure(actualExtent)

    atColIndex += 1
    if atColIndex > maxColIndex:
      atColIndex = 0
      if atRowIndex < maxRowIndex:
        atRowIndex += 1

  vec2(
    metricsX.staticExtent + remainingX,
    metricsY.staticExtent + remainingY
  )


method arrangeOverride(self: Grid, arrangeSize: Vec2[float]): Vec2[float] =
  let props = self.gridProps

  let maxColIndex = props.cols.len() - 1
  let maxRowIndex = props.rows.len() - 1
  var atColIndex = 0
  var atRowIndex = 0

  var nextPos = vec2(0.0)

  for child in self.children:
    let colSpec = props.cols[atColIndex]
    let rowSpec = props.rows[atRowIndex]

    let box = rect(nextPos, vec2(colSpec.actualExtent, rowSpec.actualExtent))
    child.arrange(box)
    
    atColIndex += 1
    nextPos.x += colSpec.actualExtent
    if atColIndex > maxColIndex:
      nextPos.x = 0.0
      nextPos.y += rowSpec.actualExtent
      atColIndex = 0
      if atRowIndex < maxRowIndex:
        atRowIndex += 1

  self.desiredSize.get()

proc initGrid*(self: Grid, props: GridProps): void =
  self.gridProps = props

proc createGrid*(props: (ElementProps, GridProps)): Grid =
  let (elemProps, gridProps) = props
  result = Grid()
  initElement(result, elemProps)
  initGrid(result, gridProps)
