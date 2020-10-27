import macros, sugar, sets, sequtils, tables, options, strformat
import ../types, ../data_binding, ../element, ../behaviors
import ../containers/stack, ../containers/dock
import ../primitives/text, ../primitives/rectangle
import ../native_element
import ../../utils
import ../../guid
import spread_operator_implementations

import macroutils except name, body
import ../../observables

export macros
export types
export spread_operator_implementations
export utils
export behaviors
export observables
export element

type
  NoProps* = ref object ## \
    ## Used for element types that don't have their own props type, as a filler type.

  ElementParts[T] = tuple[elemProps: ElemProps, componentProps: T, children: seq[Element]]

  MemberTable = OrderedTable[string, NimNode]

proc extractMembersFromPropsType(propType: NimNode): OrderedTable[string, NimNode] =
  let pt = propType.getType()[1]
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

macro extractProps*(propType: typed, attributes: typed): untyped =
  let propsTypeMembers = extractMembersFromPropsType(propType)
  let elemPropsMembers = extractMembersFromElemProps()
  let propName = propType.strVal
  let elemProps = ObjConstr(
    Ident("ElemProps")
  )
  let componentProps = ObjConstr(
    Ident(propName)
  )
  for attr in attributes:
    case attr.kind:
      of nnkTupleConstr:
        let fieldName = attr[0].strVal
        let node = attr[1]
        let nodeType = node.getTypeInst()
        let fieldInitializer = ExprColonExpr(Ident(fieldName), node)
        if propsTypeMembers.hasKey(fieldName):
          let propsType = propsTypeMembers[fieldName].getTypeInst()
          componentProps.add(fieldInitializer)

        elif elemPropsMembers.hasKey(fieldName):
          let propsType = elemPropsMembers[fieldName].getTypeInst()
          elemProps.add(fieldInitializer)
        else:
          error(&"Field '{fieldName}' not found on type <{propName}>")
      of nnkEmpty: discard
      else:
        echo "Attr repr: ", attr.treeRepr()
        error(&"Attribute error for '{attr.repr()}' type of <{attr.getType().repr()}> not supported")

  quote do:
    (elemProps: `elemProps`, componentProps: `componentProps`)

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

# TODO: Remove this proc
template rectangle_impl*(attributes: untyped): untyped =
  block:
    let elemParts = extractProps(RectProps, attributes)
    createRectangle(elemParts.componentProps, elemParts.elemProps)

macro extractChildren*(childrenOrBehaviors: typed, childrenIdent: untyped, behaviorsIdent: untyped): untyped =
  let children = Bracket()
  let behaviors = Bracket()
  for item in childrenOrBehaviors:
    if item.getTypeInst().sameType(Element.getType()):
      children.add item
    elif item.getTypeInst().sameType(Behavior.getType()):
      behaviors.add item
  result = quote do:
    var
      `childrenIdent`: seq[Element] = @`children`
      `behaviorsIdent`: seq[Behavior] = @`behaviors`

# TODO: Find a non-dirty way to do this
# This is just a helper template to make it faster to implement all
# the GUI primitives
template element_type(attributesAndChildren: untyped, propsType: untyped, constructor: untyped): untyped =
  let expanded = expandNiceAttributeSyntax(attributesAndChildren)
  let attributes = expanded.attributes.toNimNode()
  let bindingsTuples = expanded.bindings.toNimNode()
  let childrenAndBehaviors = expanded.children.toNimNode()
  let restStatements = expanded.restStatements

  # A collection of child lists that have been applied with the `...` operator (spread operator)
  # Each child in each of these lists should be added to the children list of this element
  let childCollections = expanded.childCollections.toNimNode()
  #let childCollectionsForTypeChecking = expanded.childCollections.toNimNode()

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

  result = BlockStmt(
    StmtList(
      LetSection(
        IdentDefs(
          Ident "elemParts",
          Empty(),
          Call(
            Ident "extractProps",
            quote do:
              propsType,
            attributes
          )
        )
      ),
      restStatements,
      Call(Ident"extractChildren", childrenAndBehaviors, childrenSym, behaviorsSym),
      LetSection(
        IdentDefs(
          elementSym,
          Empty(),
          Call(
            quote do:
              constructor,
            DotExpr(Ident "elemParts", Ident "componentProps"),
            DotExpr(Ident "elemParts", Ident "elemProps"),
            childrenSym
          )
        )
      ),
      Call(
        Ident "extractBindings",
        elementSym,
        Ident "elemParts",
        quote do:
          propsType,
        bindingsTuples
      ),
      ForStmt(
        [Ident "behavior"],
        behaviorsSym,
        Call(DotExpr(elementSym, Ident "addBehavior"), Ident "behavior")

      ),
      genCollectionBindings(elementSym),
      elementSym
    )
  )
  echo "RESULT IS: ", result.repr()

macro rectangle*(attributesAndChildren: varargs[untyped]): untyped =
  element_type(attributesAndChildren, RectProps, createRectangle)

macro path*(attributesAndChildren: varargs[untyped]): untyped =
  element_type(attributesAndChildren, PathProps, createPath)

macro stack*(attributesAndChildren: varargs[untyped]): untyped =
  element_type(attributesAndChildren, StackProps, createStack)

macro scrollView*(attributesAndChildren: varargs[untyped]): untyped =
  element_type(attributesAndChildren, ScrollViewProps, createScrollView)

proc newElement(compProps: NoProps, elemProps: ElemProps, children: seq[Element]): Element = 
  newElement(elemProps, children)

macro panel*(attributesAndChildren: varargs[untyped]): untyped =
  element_type(attributesAndChildren, NoProps, newElement)

proc createDock(props: NoProps, elemProps: ElemProps, children: seq[Element]): Element =
  createDock(elemProps, children)

macro dock*(attributesAndChildren: varargs[untyped]): untyped =
  ## An element with a docking layout::
  ##
  ##   dock:
  ##     docking(DockDirection.Right):
  ##       rectangle(color = "red", width = 50.0)
  ##     docking(DockDirection.Top):
  ##       rectangle(color = "blue", height = 50.0)
  ##     rectangle(color = "green")
  ##
  element_type(attributesAndChildren, NoProps, createDock)

template docking*(dir: DockDirection, element: Element): untyped =
  block:
    let elem = element
    setDocking(elem, dir)
    elem


proc createText(props: TextProps = TextProps(), elemProps: ElemProps = ElemProps(), children: seq[Element]): Element =
  createText(props, elemProps)

macro text*(attributesAndChildren: varargs[untyped]): untyped =
  element_type(attributesAndChildren, TextProps, createText)

macro container*(attributesAndChildren: varargs[untyped]): untyped =
  element_type(attributesAndChildren, NoProps, container)

macro circle*(attributesAndChildren: varargs[untyped]): untyped =
  element_type(attributesAndChildren, CircleProps, createCircle)

proc createTextInput(props: TextInputProps, elemProps: ElemProps, children: seq[Element]): Element =
  createTextInput(props)

macro textInput*(attributesAndChildren: varargs[untyped]): untyped =
  element_type(attributesAndChildren, TextInputProps, createTextInput)

# TODO: Make binding syntax (foo <- observable), work for components
# One currently has to make the prop an observable and bind inside the component for this to work.
# This might be an ok solution for now though
macro component*(head: untyped, body: untyped): untyped =
  var compName: NimNode
  var props: seq[NimNode] = @[]
  case head.kind:
    of nnkObjConstr:
      head.expectKind(nnkObjConstr)
      compName = head[0]
      for i in [1..head.len() - 1]:
        props.add(head[i])
    of nnkCall:
      compName = head[0]
    else:
      error(&"Error creating prop. Expected identifier, but got <{head.treeRepr()}>")

  let propsIdent = Ident(compName.strVal & "Props")
  let createCompIdent = Ident("create" & compName.strVal)

  # Let bindings for the props so that they can be used in the body
  var typeBody = nnkRecList.newTree()
  var expandedProps = LetSection()
  for prop in props:
    expandedProps.add(IdentDefs(prop[0], Empty(), DotExpr(Ident("props"), prop[0])))
    typeBody.add(IdentDefs(PostFix(Ident("*"), prop[0]), prop[1], Empty()))

  let propsArgIdent = Ident("props")

  let typeDef = TypeSection(TypeDef(PostFix(Ident("*"), propsIdent), Empty(), RefTy(ObjectTy(Empty(), Empty(), typeBody))))

  let childrenIdent = Ident("children")

  result = quote do:
    `typeDef`

    macro `compName`*(attributesAndChildren: varargs[untyped]): untyped =
      element_type(attributesAndChildren, `propsIdent`, `createCompIdent`)

    proc `createCompIdent`*(`propsArgIdent`: `propsIdent`, elemProps: ElemProps, `childrenIdent`: seq[Element]): Element =
      `expandedProps`
      `body`
