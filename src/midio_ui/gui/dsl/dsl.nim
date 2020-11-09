import macros, sugar, sets, sequtils, tables, options, strformat, strutils
import ../types, ../data_binding, ../element, ../behaviors
import ../containers/stack, ../containers/dock, ../containers/scroll_view
import ../primitives/text, ../primitives/rectangle, ../primitives/path, ../primitives/circle
import ../native_element
import ../../utils
import ../../guid
import spread_operator_implementations

import macroutils except name, body
import rx_nim

export macros
export types
export spread_operator_implementations
export utils
export behaviors
export rx_nim
export element

proc withLowerCaseFirst(inp: string): string =
  result = inp
  result[0] = result[0].toLowerAscii
proc withUpperCaseFirst(inp: string): string =
  result = inp
  result[0] = result[0].toUpperAscii


type
  NoProps* = ref object ## \
    ## Used for element types that don't have their own props type, as a filler type.

  MemberTable = OrderedTable[string, NimNode]

  PropsMembers = tuple
    objects: OrderedTable[string, NimNode]
    typeMembers: OrderedTable[string, HashSet[string]]

proc extractMembersFromPropsTypes(propTypes: NimNode): PropsMembers =
  propTypes.expectKind(nnkTupleConstr)
  var propObjects = initOrderedTable[string, NimNode]()
  var propTypeMembers = initOrderedTable[string, HashSet[string]]()
  for propType in propTypes:
    let propName = propType.strVal

    let objType = propType.getTypeImpl()[0].getTypeImpl()[2]
    var members = initHashSet[string]()
    for member in objType:
      members.incl(member[0].strVal)
    propTypeMembers[propName] = members
    propObjects[propName] = ObjConstr(
      Ident(propName)
    )
  (
    objects: propObjects,
    typeMembers: propTypeMembers
  )

macro extractProps*(propTypes: typed, attributes: typed): untyped =
  let (propObjects, propTypeMembers) = extractMembersFromPropsTypes(propTypes)
  for attr in attributes:
    block attributeBlock:
      case attr.kind:
        of nnkTupleConstr:
          let fieldName = attr[0].strVal
          let node = attr[1]
          let nodeType = node.getTypeInst()
          let fieldInitializer = ExprColonExpr(Ident(fieldName), node)
          for propType in propTypes:
            let propName = propType.strVal
            if propTypeMembers[propName].contains(fieldName):
              propObjects[propName].add(fieldInitializer)
              break attributeBlock

          # NOTE: If we tried all the prop types but none matched
          # then this Element type doesn't support the supplied attribute.
          var propNamesList = ""
          for pt in propTypes:
            propNamesList = propNamesList & " " & pt.name.strVal
          error(&"Field '{fieldName}' not found on any of the possible types: <{propNamesList}>")
        of nnkEmpty: discard
        else:
          echo "Attr repr: ", attr.treeRepr()
          error(&"Attribute error for '{attr.repr()}' type of <{attr.getType().repr()}> not supported")

  result = Par()
  for p in propObjects.pairs.toSeq:
    let (propName, propObject) = p
    result.add(propObject)

template bindPropWithInvalidation*[T](elem: Element, propType: untyped, prop: untyped, observable: Observable[T]): untyped =
  # TODO: Handle disposing of subscription
  discard observable.subscribe(
    proc(newVal: T): void =
      elem.propType.prop = newVal
      elem.invalidateLayout()
  )

proc createBinding(element: NimNode, targetProp: NimNode, attrib: NimNode, sourceObservable: NimNode): NimNode =
  # HACK: To allow the ElementProps field on Element to be named props instaed of elementProps.
  let tp =
    if targetProp.strVal == "elementProps":
      Ident("props")
    else:
      targetProp
  quote do:
    bindPropWithInvalidation(`element`, `tp`, `attrib`, `sourceObservable`)

macro extractBindings*(element: untyped, propTypes: typed, attributes: typed): untyped =
  let (propObjects, propTypeMembers) = extractMembersFromPropsTypes(propTypes)
  let bindings = StmtList()
  for attr in attributes:
    block attributesBlock:
      case attr.kind:
        of nnkTupleConstr:
          let fieldName = attr[0].strVal
          let node = attr[1]
          for propType in propTypes:
            let propName = propType.strVal
            if propTypeMembers[propName].contains(fieldName):
              var propNameWithLowerFirst = propName
              propNameWithLowerFirst[0] = propNameWithLowerFirst[0].toLowerAscii
              let propsFieldIdent = Ident(propNameWithLowerFirst)
              bindings.add(createBinding(element, propsFieldIdent, Ident(fieldName), node))
              break attributesBlock
          var propNamesList = ""
          for pt in propTypes:
            propNamesList = propNamesList & " " & pt.name.strVal
          error(&"Field '{fieldName}' not found on any of the possible props types <{propNamesList}>")
        of nnkEmpty: discard
        else:
          echo "Attr repr: ", attr.treeRepr()
          error(&"Attribute error for '{attr.repr()}' type of <{attr.getType().repr()}> not supported")
  result = bindings



type
  Binding = tuple
    target: NimNode
    source: NimNode
  Attribute = tuple
    attrib: NimNode
    value: NimNode
  ChildOrBehavior = NimNode
  ChildCollection = NimNode

proc toNimNode*(self: Attribute): NimNode =
  nnkTupleConstr.newTree(self.attrib.toStrLit(), self.value)

proc toNimNode*(self: seq[Attribute]): NimNode =
  result = nnkTupleConstr.newTree()
  for attr in self:
    result.add(attr.toNimNode())

proc toNimNode*(self: Binding): NimNode =
  nnkTupleConstr.newTree(self.target.toStrLit(), self.source)

proc toNimNode*(self: seq[Binding]): NimNode =
  result = nnkTupleConstr.newTree()
  for binding in self:
    result.add(binding.toNimNode())

proc toNimNode*(self: seq[ChildOrBehavior]): NimNode =
  result = nnkTupleConstr.newTree()
  for child in self:
    result.add(child)

proc toNimNodeList*(self: seq[NimNode]): NimNode =
  let items = Bracket()
  for node in self:
    items.add(node)
  Prefix(Ident("@"), items)

type
  ExpandedNiceSyntax = ref object
    attributes: seq[Attribute]
    children: seq[NimNode]
    childCollections: seq[ChildCollection]
    bindings: seq[Binding]
    restStatements: NimNode


## Goes from 'foo="bar", baz="123"'', to (("foo", "bar"), ("baz", 123))
## Creates data-bindings for 'foo<-bar', if bar is an Observable
## If item is an element type, it becomes a child.
proc expandNiceAttributeSyntax*(attributesAndChildren: NimNode): ExpandedNiceSyntax =
  var attributes: seq[Attribute] = @[]
  var childrenAndBehaviors: seq[ChildOrBehavior] = @[]
  var spreadChildListsAndObservables: seq[NimNode] = @[]
  var bindings: seq[Binding] = @[]
  # NOTE: `restStatementList` contains all statements in body which are not children, behaviors or attributes
  var restStatementList = StmtList()
  for attr in attributesAndChildren:
    case attr.kind:
      of nnkInfix:
        let operator = attr[0].strVal
        let leftHand = attr[1]
        let rightHand = attr[2]
        case operator:
          of "<-":
            bindings.add((target: leftHand, source: rightHand))
          else:
            error(&"Unsupported operator for attribute assignment: <{operator}>.")
      of nnkExprEqExpr:
        attr.expectKind(nnkExprEqExpr)
        attributes.add((attrib: attr[0], value: attr[1]))
      of nnkStmtList:
        for child in attr:
          case child.kind:
            of nnkPrefix:
              if child[0].strVal == "...":
                spreadChildListsAndObservables.add(child[1])
            # This allows us to create let and var bindings in element bodies
            of nnkLetSection, nnkVarSection, nnkBlockStmt, nnkProcDef, nnkDiscardStmt:
              restStatementList.add(child)
            else:
              # We do typechecking later in a later pass
              # since we do not yet have type information here
              childrenAndBehaviors.add(child)
      of nnkCall:
          childrenAndBehaviors.add(attr)
      else:
        error(&"Item of kind <{attr.kind}>, is not supported")
  ExpandedNiceSyntax(
    attributes: attributes,
    children: childrenAndBehaviors,
    childCollections: spreadChildListsAndObservables,
    bindings: bindings,
    restStatements: restStatementList,
  )

macro safeCastToElement*(self: string or int or float): untyped =
  error("strings and numbers are children is not supported")

proc safeCastToElement*[T](self: T): Element =
  if self is Element:
    cast[Element](self)
  else:
    # TODO: Make this check static, if possible.
    # TODO: Make safeCastToElement report exactly where the error is and what went wrong.
    raise newException(Exception, "Child did not inherit from Element")

macro extractChildren*(childrenOrBehaviors: typed, childrenIdent: untyped, behaviorsIdent: untyped): untyped =
  let children = Bracket()
  let behaviors = Bracket()
  for item in childrenOrBehaviors:
    if item.getTypeInst().sameType(Behavior.getType()):
      behaviors.add item
    else:
      # NOTE: Assyming all other items inherit from Element and are valid children.
      # This is autmatically verified later, by the type system after macro expansion.
      children.add Call(Ident"safeCastToElement", item)
  result = quote do:
    var
      `childrenIdent`: seq[Element] = @`children`
      `behaviorsIdent`: seq[Behavior] = @`behaviors`

macro expandSyntax*(propTypes: untyped, constructor: untyped, attributesAndChildren: varargs[untyped]): untyped =
  let expanded = expandNiceAttributeSyntax(attributesAndChildren)
  let attributes = expanded.attributes.toNimNode()
  let bindingsTuples = expanded.bindings.toNimNode()
  let childrenAndBehaviors = expanded.children.toNimNode()
  let restStatements = expanded.restStatements


  # A collection of child lists that have been applied with the `...` operator (spread operator)
  # Each child in each of these lists should be added to the children list of this element
  let childCollections = expanded.childCollections.toNimNode()
  let
    childrenSym = Ident"children" # genSym(nskVar, "children")
    behaviorsSym = genSym(nskVar, "behaviors")

  var elementSym = Ident"this"
  proc genCollectionBindings(): NimNode =
    let collectionBindings = StmtList()
    for collection in childCollections:
        # We expect any type that is spread using ... to have this method implemented for it
        # (var seq[Element], T) -> void
      let bindCall = newCall(Ident "bindChildCollection", elementSym, collection)
      collectionBindings.add(bindCall)
    collectionBindings

  let childCollectionBindings = genCollectionBindings()

  result = BlockStmt(
    StmtList(
      LetSection(
        IdentDefs(
          Ident"props",
          Empty(),
          Call(
            Ident "extractProps",
            propTypes,
            attributes
          )
        )
      ),
      # TODO: Readd rest statements
      restStatements,
      Call(Ident"extractChildren", childrenAndBehaviors, childrenSym, behaviorsSym),
      LetSection(
        IdentDefs(
          elementSym,
          Empty(),
          Call(
            constructor,
            Ident"props"
          )
        )
      ),
      Call("addChildren", elementSym, childrenSym),
      Call(
        Ident "extractBindings",
        elementSym,
        propTypes,
        bindingsTuples
      ),
      ForStmt(
        [Ident "behavior"],
        behaviorsSym,
        Call(DotExpr(elementSym, Ident "addBehavior"), Ident "behavior")
      ),
      childCollectionBindings,
      elementSym
    )
  )

template element_type(identifier: untyped, propTypes: untyped, constructor: untyped): untyped =
  template `identifier`*(attributesAndChildren: varargs[untyped]): untyped =
    expandSyntax(
      propTypes,
      constructor,
      attributesAndChildren,
    )

element_type(rectangle, (ElementProps, RectangleProps), createRectangle)
element_type(path, (ElementProps, PathProps), createPath)
element_type(stack, (ElementProps, StackProps), createStack)
element_type(scrollView, (ElementProps, ScrollViewProps), createScrollView)

type
  PanelElem* = ref object of Element
  PanelProps* = ref object

proc initPanel*(self: PanelElem): void =
  discard
proc createPanel*(props: (ElementProps, PanelProps)): PanelElem =
  result = PanelElem()
  initElement(result, props[0])

element_type(panel, (ElementProps, PanelProps), createPanel)

## An element with a docking layout::
##
##   dock:
##     docking(DockDirection.Right):
##       rectangle(color = "red", width = 50.0)
##     docking(DockDirection.Top):
##       rectangle(color = "blue", height = 50.0)
##     rectangle(color = "green")
##
element_type(dock, (ElementProps, DockProps), createDock)

template docking*(dir: DockDirection, element: Element): Element =
  block:
    let elem = element
    setDocking(elem, dir)
    elem

element_type(text, (ElementProps, TextProps), createText)
element_type(circle, (ElementProps, CircleProps), createCircle)
element_type(textInput, (ElementProps, TextInputProps), createTextInput)

# TODO: Make binding syntax (foo <- observable), work for components
# One currently has to make the prop an observable and bind inside the component for this to work.
# This might be an ok solution for now though
macro component*(args: varargs[untyped]): untyped = #parentType: untyped, head: untyped, body: untyped): untyped =
  let (head, body) =
    if args.len == 3:
      (args[1], args[2])
    else:
      (args[0], args[1])

  var name: NimNode
  var props = nnkTupleConstr.newTree()
  case head.kind:
    of nnkObjConstr:
      head.expectKind(nnkObjConstr)
      name = head[0]
      for i in [1..head.len() - 1]:
        props.add(head[i])
    of nnkCall:
      name = head[0]
    else:
      error(&"Error creating prop. Expected identifier, but got <{head.treeRepr()}>")

  var nameStrUpperFirst = name.strVal
  nameStrUpperFirst[0] = name.strVal[0].toUpperAscii()
  var nameStrLowerFirst = name.strVal
  nameStrLowerFirst[0] = name.strVal[0].toLowerAscii()

  let compName = Ident(nameStrUpperFirst)
  let compConstructorName = Ident(name.strVal.withLowerCaseFirst)
  let propsTypeIdent = Ident(nameStrUpperFirst & "Props")

  let createCompIdent = Ident("create" & nameStrUpperFirst)

  # Let bindings for the props so that they can be used in the body



  let propsArgIdent = Ident("props")

  let childrenIdent = Ident("children")


  let parentType =
    if args.len == 3:
      args[0]
    else:
      Ident"Element"

  let parentInitProc =
    if args.len == 3:
      Ident("init" & parentType.strval)
    else:
      Empty()
  let propsTypeTuple =
    if args.len == 3:
      Par(
        Ident"ElementProps",
        Ident(parentType.strVal & "Props"),
        propsTypeIdent
      )
    else:
      Par(
        Ident"ElementProps",
        propsTypeIdent
      )

  let compPropsIdent = Ident(propsTypeIdent.strVal.withLowerCaseFirst)
  let parentPropsIdent = Ident(parentType.strVal.withLowerCaseFirst & "Props")
  let elemPropsIdent = Ident("elementProps")

  var typeBody = nnkRecList.newTree()
  if props.len() > 0:
    for prop in props:
      typeBody.add(IdentDefs(PostFix(Ident("*"), prop[0]), prop[1], Empty()))


  let typeDef = TypeSection(
    TypeDef(
      PostFix(Ident("*"), propsTypeIdent), Empty(), RefTy(ObjectTy(Empty(), Empty(), typeBody))
    )
  )

  let initCompSym = Ident("init" & nameStrUpperFirst)

  let propsIdent = Ident"props"
  let contentSym = genSym(nskLet, "content")
  let createCompProcBody = StmtList(
    if args.len == 3:
      LetSection(
        IdentDefs(compPropsIdent, Empty(), BracketExpr(propsIdent, Lit(2))),
        IdentDefs(parentPropsIdent, Empty(), BracketExpr(propsIdent, Lit(1))),
        IdentDefs(elemPropsIdent, Empty(), BracketExpr(propsIdent, Lit(0))),
      )
    else:
      LetSection(
        IdentDefs(compPropsIdent, Empty(), BracketExpr(propsIdent, Lit(1))),
        IdentDefs(elemPropsIdent, Empty(), BracketExpr(propsIdent, Lit(0))),
      ),
    LetSection(
      IdentDefs("ret", Empty(), Call(compName))
    ),
    Call("initElement", Ident"ret", elemPropsIdent),
    LetSection(
      IdentDefs(contentSym, Empty(), BlockStmt(Call(Ident"compileComponentBody", propsTypeTuple, props, compPropsIdent, body)))
    ),
    nnkLetSection.newTree(
      nnkVarTuple.newTree(Ident"children", Ident"behaviors", Empty(), contentSym)
    ),
    if args.len == 3:
      Call(parentInitProc, Ident"ret", parentPropsIdent)
    else:
      Empty()
    ,
    Call(initCompSym, Ident"ret", compPropsIdent),
    Call("addChildren", Ident"ret", Ident"children"),
    ForStmt(
      [Ident"b"],
      Ident"behaviors",
      Call(DotExpr(Ident"ret", Ident"addBehavior"), Ident"b")
    ),
    Ident"ret"
  )


  result = quote do:
    `typeDef`

    type
      `compName`* = ref object of `parentType`
        `compPropsIdent`*: `propsTypeIdent`

    proc `initCompSym`*(self: `compName`, props: `propsTypeIdent`): void =
      self.`compPropsIdent` = props

    converter toElementOption*(self: Option[`compName`]): Option[Element] =
      self.map((x: `compName`) => x.Element)

    converter toObservableElementOption*(self: Observable[Option[`compName`]]): Observable[Option[Element]] =
      self.map(toElementOption)

    converter toSubjectElementOption*(self: Subject[Option[`compName`]]): Observable[Option[Element]] =
      self.map(toElementOption)

    template `compConstructorName`*(attributesAndChildren: varargs[untyped]): untyped =
      expandSyntax(
        `propsTypeTuple`,
        `createCompIdent`,
        attributesAndChildren,
      )

    proc `createCompIdent`*(`propsIdent`: `propsTypeTuple`): `compName` =
      `createCompProcBody`


# TODO: parse body so that we can have multiple children and specify a root type in the "constructor"


macro sortChildren*(childrenTuple: untyped): untyped =
  let behaviors = Bracket()
  let children = Bracket()
  for child in childrenTuple:
    if child.getTypeInst().sameType(Behavior.getType()):
      behaviors.add(child)
    else:
      children.add(Call(Ident"safeCastToElement", child))
  result = StmtList(
    LetSection(
      IdentDefs(
        Ident"children",
        quote do:
          seq[Element],
        Prefix(Ident"@", children)
      ),
      IdentDefs(
        Ident"behaviors",
        quote do:
          seq[Behavior],
        Prefix(Ident"@", behaviors)
      )
    ),
    Par(Ident"children", Ident"behaviors")
  )

type
  PropsType = tuple
    propType: NimNode
    attributeIdentifier: NimNode
# TODO: Split into multiple procs
proc getPropsTypeForIdentifier(propTypes: NimNode, identifier: NimNode): Option[PropsType] =
  propTypes.expectKind(nnkTupleConstr)
  identifier.expectKind(nnkIdent)
  for propType in propTypes:
    let objType = propType.getTypeImpl()[0].getTypeImpl()[2]
    for member in objType:
      if member[0].strVal == identifier.strVal:
        return some((propType, member[0]))

proc getMembersOfPropsType(propType: NimNode): seq[NimNode] =
  let objType = propType.getTypeImpl()[0].getTypeImpl()[2]
  result = @[]
  for member in objType:
    result.add member

proc propTypeAndAttribToNimNode(propType: NimNode, attr: NimNode): NimNode =
  DotExpr(Ident(propType.strVal.withLowerCaseFirst), attr)

macro binding[T](elem: untyped, prop: untyped, observable: Observable[T]): untyped =
  # TODO: Handle disposing of subscription
  result = quote do:
    discard `observable`.subscribe(
      proc(newVal: auto): void =
        `prop` = newVal
        `elem`.invalidateLayout()
    )

proc createBinding(attrib: NimNode, sourceObservable: NimNode): NimNode =
  let elemIdent = Ident"ret"
  quote do:
    binding(`elemIdent`, `attrib`, `sourceObservable`)

macro compileComponentBody*(propTypes: typed, componentProps: untyped, compPropsIdent: untyped, body: untyped): untyped =
  let content = StmtList()
  var children: seq[(NimNode, NimNode)] = @[]

  var expandedProps =
    block:
      let section =  StmtList()
      for propType in propTypes:
        let propsMembers = getMembersOfPropsType(propType)
        var propIdent = Ident propType.strVal.withLowerCaseFirst
        for prop in propsMembers:
          let getter = TemplateDef(
            Ident(&"{prop[0].strVal}"),
            Empty(),
            Empty(),
            FormalParams(
              prop[1]
            ),
            Empty(),
            StmtList(
              DotExpr(propIdent, prop[0])
            )
          )
          let setter = TemplateDef(
            Ident(&"`{prop[0].strVal}=`"),
            Empty(),
            Empty(),
            FormalParams(
              Ident("void"),
              IdentDefs(
                Ident("val"),
                prop[1],
                Empty()
              ),
            ),
            Empty(),
            StmtList(
              Asgn(DotExpr(propIdent, prop[0]), Ident"val")
            )
          )
          section.add(getter)
          section.add(setter)
      section

  for item in body:
    case item.kind:
      of nnkCall, nnkIdent:
        children.add((genSym(nskLet, "child"), item))
      of nnkInfix:
        let operator = item[0].strVal
        let leftHand = item[1]
        let rightHand = item[2]
        case operator:
          of "<-":
            content.add(createBinding(leftHand, rightHand))
          else:
            content.add(item)
      else:
        content.add(item)

  let childrenDefinitions = LetSection()
  for c in children:
    let (sym, def) = c
    childrenDefinitions.add(IdentDefs(sym, Empty(), def))
  let childrenTuple = Par()
  for c in children:
    let (sym, _) = c
    childrenTuple.add(sym)

  result = StmtList(
    expandedProps,
    content,
    childrenDefinitions,
    Call(Ident"sortChildren", childrenTuple)
  )
