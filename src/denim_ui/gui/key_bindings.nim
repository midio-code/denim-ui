import tables
import sugar
import types

type
  KeyBinding* = ref object
    key*: string
    command*: () -> void

var bindings: Table[Element, seq[KeyBinding]] = initTable[Element, seq[KeyBinding]]()

proc bindKey*(self: Element, key: string, command: () -> void): void =
  var elemBindings: seq[KeyBinding] = bindings.mgetorput(self, @[])
  elemBindings.add(KeyBinding(
    key: key,
    command: command,
  ))
