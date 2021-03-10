import tables
import sugar
import types
import behaviors
import options
import strutils

type
  Command = () -> void
  KeyCombo = ref object
    key*: string
    modifier*: Option[string]
  KeyBinding* = ref object
    keyCombo*: KeyCombo
    command*: () -> void

var bindings: Table[Element, seq[KeyBinding]] = initTable[Element, seq[KeyBinding]]()

proc parseKeyCombo(self: string): KeyCombo =
  if self.contains("-"):
    let parts = self.split("-")
    if parts.len != 2:
      raise newException(Exception, "Key combo can at most contain one dash (-)")
    result = KeyCombo(
      key: parts[1],
      modifier: some(parts[0])
    )
  else:
    result = KeyCombo(
      key: self,
      modifier: none[string]()
    )

proc bindKey*(self: Element, keyComboStr: string, command: () -> void): void =
  bindings.mgetorput(self, @[]).add(
    KeyBinding(
      keyCombo: parseKeyCombo(keyComboStr),
      command: command,
    )
  )

iterator matchingBindings(self: seq[KeyBinding], args: KeyArgs): KeyBinding =
  for binding in self:
    if binding.keyCombo.key == args.key:
      if binding.keyCombo.modifier.isSome and binding.keyCombo.modifier.get in args.modifiers:
        yield binding
      elif binding.keyCombo.modifier.isNone:
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
