import tables
import sets
import sugar
import types
import behaviors
import options
import strformat
import strutils
import algorithm

type
  Command* = () -> void
  KeyCombo = ref object
    key*: string
    modifiers*: seq[string]
  KeyBinding* = ref object
    keyCombo*: KeyCombo
    command*: Command

proc `$`(self: KeyCombo): string =
  &"KeyCombo(key: {self.key}, modifiers: {self.modifiers})"

proc `$`(self: KeyBinding): string =
  &"KeyBinding(key: {self.keyCombo})"

const recognizedModifiers = toHashSet(["Shift", "Meta", "Ctrl", "Alt"])

var globalBindings: seq[KeyBinding] = @[]
var bindings: Table[Element, seq[KeyBinding]] = initTable[Element, seq[KeyBinding]]()

proc parseKeyCombo(self: string): KeyCombo =
  if self.contains("-"):
    let parts = self.split("-")
    var modifiers: seq[string] = @[]
    var key = none[string]()
    for part in parts:
      if part in recognizedModifiers:
        modifiers.add(part)
      elif key.isNone:
        key = some(part)

    if key.isNone:
      raise newException(Exception, &"Key binding requies a key as part of its pattern, but none was found: {self}")

    result = KeyCombo(
      key: key.get,
      modifiers: modifiers
    )
  else:
    result = KeyCombo(
      key: self,
      modifiers: @[]
    )

proc bindKey*(self: Element, keyComboStr: string, command: Command): void =
  bindings.mgetorput(self, @[]).add(
    KeyBinding(
      keyCombo: parseKeyCombo(keyComboStr),
      command: command,
    )
  )

proc bindGlobalKey*(self: Element, keyComboStr: string, command: Command): void =
  globalBindings.add(
    KeyBinding(
      keyCombo: parseKeyCombo(keyComboStr),
      command: command,
    )
  )

proc compareLength(self, other: KeyBinding): int =
  other.keyCombo.modifiers.len - self.keyCombo.modifiers.len

proc bestMatchingBinding(self: seq[KeyBinding], args: KeyArgs): Option[KeyBinding] =
  let bindingsSortedOnModifiersLength = self.sorted(compareLength)
  for binding in bindingsSortedOnModifiersLength:
    if binding.keyCombo.key == args.key:
      if toHashSet(binding.keyCombo.modifiers) <= toHashSet(args.modifiers):
        return some(binding)

proc dispatchKeyBindings*(self: Element, args: KeyArgs): void =
  if self in bindings:
    let elemBindings = bindings[self]
    let matchingBinding = elemBindings.bestMatchingBinding(args)
    if matchingBinding.isSome:
      matchingBinding.get.command()

proc dispatchGlobalKeyBindings*(args: KeyArgs): void =
  let matchingBinding = globalBindings.bestMatchingBinding(args)
  if matchingBinding.isSome:
    matchingBinding.get.command()

type
  KeyMapping = ref object
    mapping*: string
    handler*: Command

proc newKeyBinding*(mapping: string, handler: Command): KeyMapping =
  KeyMapping(
    mapping: mapping,
    handler: handler
  )

proc withGlobalKeyBindings*(
  bindings: seq[KeyMapping]
): Behavior =
  Behavior(
    added: some(
      proc(elem: Element): void =
        for b in bindings:
          let key = b.mapping
          let command = b.handler
          elem.bindGlobalKey(key, command)
    )
  )

proc withKeyBindings*(
  bindings: seq[KeyMapping]
): Behavior =
  Behavior(
    added: some(
      proc(elem: Element): void =
        for b in bindings:
          let key = b.mapping
          let command = b.handler
          elem.bindKey(key, command)
    )
  )

# TODO: Remove this overload
proc withKeyBindings*(
  bindings: seq[(string, Command)]
): Behavior =
  Behavior(
    added: some(
      proc(elem: Element): void =
        for (key, command) in bindings:
          elem.bindKey(key, command)
    )
  )
