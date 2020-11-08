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

type
  NoProps* = ref object ## \
    ## Used for element types that don't have their own props type, as a filler type.

  MemberTable = OrderedTable[string, NimNode]

proc extractMembersFromPropsType(propType: NimNode): OrderedTable[string, NimNode] =
  let pt = propType.getTypeInst()[1]
  if pt.kind != nnkBracketExpr:
    error(&"Prop types must be ref object types, was: <{pt.repr()}>. TODO: Implement for non ref types.")

  let propTypeInfo = propType.getType()[1].getType()[1]
  let propTypeFieldsInfo = propTypeInfo.getTypeImpl()[2]
  result = initOrderedTable[string, NimNode]()
  for m in propTypeFieldsInfo:
    result[m[0].strVal] = m[1]

proc extractMembersFromElemProps(): OrderedTable[string, NimNode] =
  result = initOrderedTable[string, NimNode]()
  for m in ElemProps.getType()[1].getTypeImpl()[2]:
    result[m[0].strVal] = m[1]

macro extractProps*(propTypes: typed, attributes: typed): untyped =
  propTypes.expectKind(nnkTupleConstr)
  var propObjects = initTable[string, NimNode]()
  var propTypeMembers = initTable[string, HashSet[string]]()
  echo "\n\nExtracting props"
  for propType in propTypes:
    let propName = propType.strVal

    let objType = propType.getTypeImpl()[0].getTypeImpl()[2]
    #objType.expectKind(nnkObjectTy)
    #echo "Obj Ty: ", objType.treeRepr()
    var members = initHashSet[string]()
    echo "Prop: ", propName
    for member in objType:
      echo "  Adding member: ", member[0].strVal
      members.incl(member[0].strVal)
    propTypeMembers[propName] = members
    propObjects[propName] = ObjConstr(
      Ident(propName)
    )

  for attr in attributes:
    block attributeBlock:
      case attr.kind:
        of nnkTupleConstr:
          let fieldName = attr[0].strVal
          let node = attr[1]
          let nodeType = node.getTypeInst()
          let fieldInitializer = ExprColonExpr(Ident(fieldName), node)
          for propType in propTypes:
            #echo "PropType: ", propType.treeRepr()
            let propName = propType.strVal
            if propTypeMembers[propName].contains(fieldName):
              echo &"Adding {fieldName} to {propName}"
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
  for p in propObjects.pairs.toSeq.reverse:
    let (propName, propObject) = p
    result.add(propObject)
  echo "Par result: ", result.repr()

template bindPropWithInvalidation*[T](elem: Element, prop: typed, observable: Observable[T]): untyped =
  # TODO: Handle disposing of subscription
  discard observable.subscribe(
    proc(newVal: T): void =
      prop = newVal
      elem.invalidateLayout()
  )

proc createBinding(element: NimNode, targetProp: NimNode, attrib: NimNode, sourceObservable: NimNode): NimNode =
  quote do:
    bindPropWithInvalidation(`element`, `targetProp`.`attrib`, `sourceObservable`)

proc createLayoutBinding(element: NimNode, attrib: NimNode, sourceObservable: NimNode): NimNode =
  quote do:
    bindLayoutProp(`element`, `attrib`, `sourceObservable`)

macro extractBindings*(element: untyped, targetProp: untyped, propType: typed, attributes: typed): untyped =
  let propsTypeMembers = extractMembersFromPropsType(propType)
  let elemPropsMembers = extractMembersFromElemProps()
  let propName = propType.strVal

  let bindings = StmtList()

  for attr in attributes:
    case attr.kind:
      of nnkTupleConstr:
        let fieldName = attr[0].strVal
        let node = attr[1]
        if propsTypeMembers.hasKey(fieldName):
          bindings.add(createBinding(element, DotExpr(targetProp, Ident("componentProps")), Ident(fieldName), node))

        elif elemPropsMembers.hasKey(fieldName):
          bindings.add(createLayoutBinding(element, Ident(fieldName), node))
        else:
          error(&"Field '{fieldName}' not found on type <{propName}>")
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
  # All statements in body which are not children, behaviors or attributes
  var restStatementList = StmtList()
  #echo "ATTRIBUTES-AND-CHILDREN: ", attributesAndChildren.treerepr()
  for attr in attributesAndChildren:
    case attr.kind:
      of nnkInfix:
        #echo "Infix: ", attr.treeRepr()
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
      of nnkIdent:
        # TODO: When just given a single identifier, use it as the name to bind the current instance to.
        error("Name binding is currently wip")
      else:
        # TODO: Support spread operator (...) on expressions, like:
        # ...foo.map(x => ....
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

macro typedPass*(
  propTypes: typed,
  constructor: typed,
  attributes: typed,
  bindingsTuples: typed,
  childrenAndBehaviors: typed,
  restStatements: typed,
  childCollections: typed
): untyped =
  let
    childrenSym = genSym(nskVar, "children")
    behaviorsSym = genSym(nskVar, "behaviors")

  proc genCollectionBindings(elemSym: NimNode): NimNode =
    let collectionBindings = StmtList()
    for collection in childCollections:
        # We expect any type that is spread using ... to have this method implemented for it
        # (var seq[Element], T) -> void
      let bindCall = newCall(Ident "bindChildCollection", elemSym, collection)
      collectionBindings.add(bindCall)
    collectionBindings

    #echo "collection bindings: ", collectionBindings.treerepr()

  # let collectionBindings = genCollectionBindings()
  # echo "COLLECTION_BINDINGS: ", collectionBindings.treerepr()

  var elementSym = genSym(nskLet, "this")
  var propsTupleIdent = Ident"propsTuple"
  result = BlockStmt(
    StmtList(
      LetSection(
        IdentDefs(
          propsTupleIdent,
          Empty(),
          Call(
            Ident "extractProps",
            propTypes,
            attributes
          )
        )
      ),
      # TODO: Readd rest statements
      #restStatements,
      Call(Ident"extractChildren", childrenAndBehaviors, childrenSym, behaviorsSym),
      LetSection(
        IdentDefs(
          elementSym,
          Empty(),
          Call(
            constructor,
            propsTupleIdent,
            childrenSym
          )
        )
      ),
      # Call(
      #   Ident "extractBindings",
      #   elementSym,
      #   Ident "elemParts",
      #   quote do:
      #     propsType,
      #   bindingsTuples
      # ),
      ForStmt(
        [Ident "behavior"],
        behaviorsSym,
        Call(DotExpr(elementSym, Ident "addBehavior"), Ident "behavior")

      ),
      genCollectionBindings(elementSym),
      elementSym
    )
  )
  echo "Result is: ", result.repr()

# TODO: Find a non-dirty way to do this
# This is just a helper template to make it faster to implement all
# the GUI primitives
macro expandSyntax*(propTypes: untyped, constructor: untyped, attributesAndChildren: varargs[untyped]): untyped =
  let expanded = expandNiceAttributeSyntax(attributesAndChildren)
  let attributes = expanded.attributes.toNimNode()
  let bindingsTuples = expanded.bindings.toNimNode()
  let childrenAndBehaviors = expanded.children.toNimNode()
  let restStatements = expanded.restStatements

  # A collection of child lists that have been applied with the `...` operator (spread operator)
  # Each child in each of these lists should be added to the children list of this element
  let childCollections = expanded.childCollections.toNimNode()
  result = Call(
    Ident"typedPass",
    propTypes,
    constructor,
    attributes,
    bindingsTuples,
    childrenAndBehaviors,
    restStatements,
    childCollections
  )

template element_type(identifier: untyped, propTypes: untyped, constructor: untyped): untyped =
  template `identifier`*(attributesAndChildren: varargs[untyped]): untyped =
    expandSyntax(
      propTypes,
      constructor,
      attributesAndChildren,
    )

element_type(rectangle, (RectProps, ElemProps), createRectangle)
element_type(path, (PathProps, ElemProps), createPath)
element_type(stack, (StackProps, ElemProps), createStack)
element_type(scrollView, (ScrollViewProps, ElemProps), createScrollView)

type
  PanelElem* = ref object of Element
  PanelProps* = ref object

proc initPanel*(self: PanelElem): void =
  discard
proc createPanel*(props: (ElemProps, PanelProps), children: seq[Element]): PanelElem =
  result = PanelElem()
  initElement(result, props[0], children)

element_type(panel, (PanelProps, ElemProps), createPanel)

## An element with a docking layout::
##
##   dock:
##     docking(DockDirection.Right):
##       rectangle(color = "red", width = 50.0)
##     docking(DockDirection.Top):
##       rectangle(color = "blue", height = 50.0)
##     rectangle(color = "green")
##
element_type(dock, (DockProps, ElemProps), createDock)

template docking*(dir: DockDirection, element: Element): untyped =
  block:
    let elem = element
    setDocking(elem, dir)
    elem


proc createText(props: (TextProps, ElemProps), children: seq[Element]): Element =
  createText(props[0], props[1])

element_type(text, (TextProps, ElemProps), createText)

element_type(circle, (CircleProps, ElemProps), createCircle)

proc createTextInput(props: (TextInputProps, ElemProps), children: seq[Element]): Element =
  createTextInput(props[1], props[0])

element_type(textInput, (TextInputProps, ElemProps), createTextInput)

# TODO: Make binding syntax (foo <- observable), work for components
# One currently has to make the prop an observable and bind inside the component for this to work.
# This might be an ok solution for now though
macro component*(parentType: untyped, head: untyped, body: untyped): untyped =
  var name: NimNode
  var props: seq[NimNode] = @[]
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

  let compName = Ident(nameStrUpperFirst & "Comp")
  let compConstructorName = Ident(nameStrUpperFirst)
  let propsTypeIdent = Ident(nameStrUpperFirst & "Props")
  let propsFieldIdent = Ident(nameStrLowerFirst& "Props")

  let createCompIdent = Ident("create" & nameStrUpperFirst)

  # Let bindings for the props so that they can be used in the body
  var typeBody = nnkRecList.newTree()
  var expandedProps =
    if props.len() > 0:
      let section =  LetSection()
      for prop in props:
        section.add(IdentDefs(prop[0], Empty(), DotExpr(Ident("props"), prop[0])))
        typeBody.add(IdentDefs(PostFix(Ident("*"), prop[0]), prop[1], Empty()))
      section
    else:
      Empty()

  let propsArgIdent = Ident("props")

  let typeDef = TypeSection(TypeDef(PostFix(Ident("*"), propsTypeIdent), Empty(), RefTy(ObjectTy(Empty(), Empty(), typeBody))))

  let childrenIdent = Ident("children")

  let parentPropsType = Ident(parentType.strVal & "Props")
  let parentInitProc = Ident("init" & parentType.strval)

  let initCompSym = Ident("init" & nameStrUpperFirst)
  let compPropsSym = genSym(nskLet, "compProps")

  result = quote do:
    `typeDef`

    type
      `compName` = ref object of `parentType`
        `propsFieldIdent`*: `propsTypeIdent`

    macro sortChildren(childrenTuple: untyped): untyped =
      let behaviors = Bracket()
      let children = Bracket()
      for child in childrenTuple:
        if child.getTypeInst().sameType(Behavior.getType()):
          behaviors.add(child)
        else:
          children.add(Call(Ident"safeCastToElement", child))
      StmtList(
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

    macro compileComponentBody(body: untyped): untyped =
      let content = StmtList()
      var children: seq[(NimNode, NimNode)] = @[]
      for item in body:
        case item.kind:
          of nnkCall:
            children.add((genSym(nskLet, "child"), item))
          of nnkLetSection, nnkVarSection, nnkDiscardStmt, nnkProcDef:
            content.add(item)
          else:
            let ik = $item.kind
            error("Node of kind <" & ik & "> is not allowed in component bodies.")
      let childrenDefinitions = LetSection()
      for c in children:
        let (sym, def) = c
        childrenDefinitions.add(IdentDefs(sym, Empty(), def))
      let childrenTuple = Par()
      for c in children:
        let (sym, _) = c
        childrenTuple.add(sym)

      StmtList(
        content,
        childrenDefinitions,
        Call(Ident"sortChildren", childrenTuple)
      )


    proc `initCompSym`*(self: `compName`, props: `propsTypeIdent`): void =
      self.`propsFieldIdent` = props

    # NOTE: Not sure why the tuple here needs to be reversed (with ElemProps first instead of last),
    # but just gonna leave it here for now, as it is not exposed to the user.
    proc `createCompIdent`*(props: (ElemProps, `parentPropsType`, `propsTypeIdent`), children: seq[Element]): `compName` =
      echo "Creating comp: "
      let
        elemProps = props[0]
        parentProps = props[1]
        `compPropsSym` = props[2]
      `expandedProps`
      let content = block:
        compileComponentBody(`body`)
      let (children, behaviors) = content
      let ret = `compName`(
        `propsFieldIdent`: `compPropsSym`,
      )
      initElement(ret, elemProps, children)
      initStack(ret, parentProps)
      for b in behaviors:
        ret.addBehavior(b)
      echo "Ret: "
      for c in ret.children:
        echo "   c: ", c.id
      ret

    template `compConstructorName`*(attributesAndChildren: varargs[untyped]): untyped =
      echo "Constructing comp"
      expandSyntax(
        (`propsTypeIdent`, `parentPropsType`, ElemProps),
        `createCompIdent`,
        attributesAndChildren,
      )

# TODO: parse body so that we can have multiple children and specify a root type in the "constructor"


