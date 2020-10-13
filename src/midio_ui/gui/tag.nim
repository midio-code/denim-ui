import types
import sets
import tables

type
  Tag* = string

var tags = initTable[Tag, HashSet[Element]]()

proc tagSet(tag: Tag): var HashSet[Element] =
  tags.mGetOrPut(tag, initHashSet[Element]())

proc addTag*(element: Element, tag: Tag): void =
  tagSet(tag).incl(element)

proc hasTag*(element: Element, tag: Tag): bool =
  tagSet(tag).contains(element)
