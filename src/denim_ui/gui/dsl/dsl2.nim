import macros
import macroutils
import options
import strutils
import strformat

# type
#   Symbol = ref object
#     sym: NimNode
#     owner: SymbolTable

#   SymbolTable = ref object
#     owner: string
#     parent: Option[SymbolTable]
#     childTables: Table[string, SymbolTable]
#     symbols: OrderedTable[string, Symbol]

# proc newSymbolTable(): SymbolTable =
#   SymbolTable(
#     owner: "<root>",
#     parent: none[SymbolTable](),
#     symbols: initOrderedTable[string, Symbol](),
#     childTables: initTable[string, SymbolTable]()
#   )

# proc add(self: SymbolTable, name: string, definition: Definition): Symbol =
#   result = Symbol(
#     sym: genSym(nskLet, name),
#     definition: definition,
#     owner: self
#   )
#   self.symbols[name] = result

# proc get(self: SymbolTable, name: string): Symbol =
#   if not self.symbols.hasKey(name):
#     if self.parent.isSome():
#       return self.parent.get().get(name)
#     else:
#       error(&"Could not find symbol: {name} on table: {self.owner}")
#   self.symbols[name]

# proc newScope(self: SymbolTable, parentSymbol: Symbol): SymbolTable =
#   result = SymbolTable(
#     owner: parentSymbol.sym.strVal(),
#     parent: some(self),
#     childTables: initTable[string, SymbolTable](),
#     symbols: initOrderedTable[string, Symbol]()
#   )
#   self.childTables[parentSymbol.sym.strVal()] = result

# proc getChild(self: SymbolTable, symbol: Symbol): SymbolTable =
#   self.childTables[symbol.sym.strVal()]

# proc getChild(self: SymbolTable, symbol: string): SymbolTable =
#   for v, k in self.childTables:
#   self.childTables[symbol]


# proc getSymbols(defs: seq[Definition], self: SymbolTable): seq[NimNode] =
#   defs.map(
#     proc(x: Definition): NimNode =
#       self.get(x.identifier).sym
#   )

type
  Prop* = object
    name*: NimNode
    `type`*: Option[NimNode]
    defaultValue*: Option[NimNode]

  Component* = object
    name*: NimNode
    parentComp*: Option[NimNode]
    props*: seq[Prop]

proc componentName*(self: Component): string =
  result = self.name.strVal
  result[0] = result[0].toUpperAscii()

proc componentIdent*(self: Component): NimNode =
  Ident(self.componentName)

proc constructorName*(self: Component): string =
  result = self.name.strVal
  result[0] = result[0].toLowerAscii()

proc constructorIdent*(self: Component): NimNode =
  Ident(self.constructorName)

proc propsTypeName*(self: Component): string =
  self.componentName & "Props"

proc propsTypeIdent*(self: Component): NimNode =
  Ident(self.propsTypeName)

proc parseProp*(arg: NimNode): Prop =
  echo "Parsing prop: ", arg.treeRepr
  case arg.kind:
    of nnkCommand:
      # prop foo: int = 123
      # prop bar: string
      assert(arg[0].strVal == "prop")
      assert(arg[2].kind == nnkStmtList)
      case arg[2][0].kind:
        of nnkIdent:
          # prop bar: string
          #  Command
          #   Ident "prop"
          #   Ident "bi"
          #   StmtList
          #     Ident "int"
          return Prop(
            name: arg[1],
            `type`: some(arg[2][0]),
          )
        of nnkAsgn:
          # prop foo: int = 123
          #  Command
          #   Ident "prop"
          #   Ident "bar"
          #   StmtList
          #     Asgn
          #       Ident "string"
          #       Infix
          #         Ident "+"
          #         StrLit "foo"
          #         Ident "bi"
          echo "Arg: ",  arg.treeRepr
          assert(arg[2][0].kind == nnkAsgn)
          return Prop(
            name: arg[1],
            `type`: some(arg[2][0][0]),
            defaultValue: some(arg[2][0][1])
          )
        else: error("Error parsing prop")
    of nnkAsgn:
      # prop baz = 321
      let command = arg[0]
      assert(command[0].strVal == "prop")
      let val = arg[1]
      return Prop(
        name: command[1],
        `type`: none[NimNode](),
        defaultValue: some(val),
      )
    else:
      error("Error parsing prop")

proc isPropIdent(node: NimNode): bool =
  node.kind == nnkIdent and node.strVal == "prop"

proc emit(self: Component): NimNode =
  Ident"foo"

macro component*(args: varargs[untyped]): untyped = #parentType: untyped, head: untyped, body: untyped): untyped =
  echo "Parsing comp: ", args.treeRepr
  if args[0].kind == nnkIdent:
    let componentName = args[0]

    let body = args[1]
    body.expectKind(nnkStmtList)

    var props: seq[Prop] = @[]
    for stmt in body:
      if stmt[0].isPropIdent:
        props.add(parseProp(stmt))

    return Component(
      name: componentName,
      props: props
    ).emit()

  else:
    error("Multiple components per component declaration is not supported yet")
