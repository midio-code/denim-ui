import options
import types
import tables

var metas = initTable[string, string]()

proc createKey(key: string, element: Element): string =
  key & ":" & $element.id

proc addMeta*(element: Element, key: string, value: string): void =
  metas[createKey(key, element)] = value

proc getMeta*(element: Element, key: string): Option[string] =
  let key = createKey(key, element)
  if metas.contains(key):
    return some(metas[key])
  else:
    return none[string]()
