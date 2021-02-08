import tables
import sugar
import types
import behaviors
import options

type
  Command = () -> void
  KeyBinding* = ref object
    key*: string
    command*: () -> void

var bindings: Table[Element, seq[KeyBinding]] = initTable[Element, seq[KeyBinding]]()

proc bindKey*(self: Element, key: string, command: () -> void): void =
  bindings.mgetorput(self, @[]).add(
    KeyBinding(
      key: key,
      command: command,
    )
  )

iterator matchingBindings(self: seq[KeyBinding], args: KeyArgs): KeyBinding =
  for binding in self:
    if binding.key == args.key:
      yield binding


proc dispatchKeyBindings*(self: Element, args: KeyArgs): void =
  if self in bindings:
    let elemBindings = bindings[self]
    for b in elemBindings.matchingBindings(args):
      b.command()

proc withKeyBindings*(
  bindings: seq[(string, () -> void)]
): Behavior =
  Behavior(
    added: some(
      proc(elem: Element): void =
        for (key, command) in bindings:
          elem.bindKey(key, command)
    )
  )
