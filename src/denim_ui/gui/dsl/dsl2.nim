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
  ComponentItem* = object
    name*: NimNode
    `type`*: Option[NimNode]
    defaultValue*: Option[NimNode]

  Prop* = object
    item*: ComponentItem

  Field* = object
    item*: ComponentItem

  AssignmentKind = enum
    Normal, Binding
  Assignment* = object
    kind*: AssignmentKind
    leftHand*: NimNode
    rightHand*: NimNode

  Component* = object
    name*: NimNode
    parentComp*: Option[NimNode]
    fields*: seq[Field]
    props*: seq[Prop]
    children*: seq[NimNode]
    body*: seq[NimNode]
    assignments*: seq[NimNode]

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

proc parseComponentItem*(arg: NimNode, keyword: string): ComponentItem =
  case arg.kind:
    of nnkCommand:
      # prop foo: int = 123
      # prop bar: string
      assert(arg[0].strVal == keyword)
      assert(arg[2].kind == nnkStmtList)
      case arg[2][0].kind:
        of nnkIdent:
          # prop bar: string
          #  Command
          #   Ident "prop"
          #   Ident "bi"
          #   StmtList
          #     Ident "int"
          return ComponentItem(
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
          assert(arg[2][0].kind == nnkAsgn)
          return ComponentItem(
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
      return ComponentItem(
        name: command[1],
        `type`: none[NimNode](),
        defaultValue: some(val),
      )
    else:
      error("Error parsing prop")

proc isPropNode(node: NimNode): bool =
  (node.kind == nnkCommand and node[0].strVal == "prop") or (node.kind == nnkAsgn and node[0].kind == nnkCommand and node[0][0].strVal == "prop")

proc isFieldNode(node: NimNode): bool =
  (node.kind == nnkCommand and node[0].strVal == "field") or (node.kind == nnkAsgn and node[0].kind == nnkCommand and node[0][0].strVal == "field")

proc isContentNode(node: NimNode): bool =
  node.kind == nnkCall

proc isAssignmentNode(node: NimNode): bool =
  node.kind == nnkAsgn

proc isPropIdent(node: NimNode): bool =
  node.kind == nnkIdent and node.strVal == "prop"

proc parseProp*(node: NimNode): Prop =
  echo "Parsing prop: ", node.treeRepr
  Prop(item: parseComponentItem(node, "prop"))

proc parseField*(node: NimNode): Field =
  Field(item: parseComponentItem(node, "field"))

proc emit(self: Component): NimNode =
  Ident"foo"

proc parseComponent*(args: NimNode): Component =
  echo "Parsing component: \n", args.treeRepr
  if args[0].kind == nnkIdent:
    var compName: NimNode
    var parentComp: Option[NimNode]
    var compBody: NimNode
    if args.kind == nnkInfix:
      assert(args[0].strVal == "of")
      compName = args[1]
      parentComp = some(args[2])
      compBody = args[3]
    else:
      compName = args[0]
      compBody = args[1]

    compBody.expectKind(nnkStmtList)

    var props: seq[Prop] = @[]
    var fields: seq[Field] = @[]
    var children: seq[NimNode] = @[]
    var assignments: seq[NimNode] = @[]
    var body: seq[NimNode] = @[]
    for stmt in compBody:
      if isPropNode(stmt):
        props.add(parseProp(stmt))
      elif isFieldNode(stmt):
        fields.add(parseField(stmt))
      elif isContentNode(stmt):
        children.add(stmt)
      elif isAssignmentNode(stmt):
        assignments.add(stmt)
      else:
        body.add(stmt)

    return Component(
      name: compName,
      parentComp: parentComp,

      props: props,
      fields: fields,
      children: children,
      assignments: assignments,
      body: body
    )

macro component*(args: varargs[untyped]): untyped = #parentType: untyped, head: untyped, body: untyped): untyped =
  echo "Parsing comp: ", args.treeRepr
  if args[0].kind == nnkIdent:
    return parseComponent(args).emit()
  else:
    error("Multiple components per component declaration is not supported yet")
