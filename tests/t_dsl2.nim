import denim_ui/gui/dsl/dsl2
import macros
import unittest
import options

template accept(e) =
  static: assert(compiles(e))

template reject(e) =
  static: assert(not compiles(e))

macro testPropWithNameAndType(): untyped =
  let prop = parseExpr("prop bi: int")
  echo "Prop stmt: ", prop.treeRepr
  let parsed = parseProp(prop)
  let p = parsed.item
  assert(p.name.strVal == "bi")
  assert(p.type.isSome)
  assert(p.type.get.kind == nnkIdent)
  assert(p.defaultValue.isNone)

testPropWithNameAndType()

macro testPropWithNameAndTypeAndDefaultValue(): untyped =
  let prop = parseExpr("prop bi: int = 123")
  echo "Prop stmt: ", prop.treeRepr
  let parsed = parseProp(prop)
  let p = parsed.item
  assert(p.name.strVal == "bi")
  assert(p.type.isSome)
  assert(p.type.get.kind == nnkIdent)
  assert(p.defaultValue.isSome)
  assert(p.defaultValue.get.kind == nnkIntLit)

testPropWithNameAndTypeAndDefaultValue()

macro testPropWithNameAndDefaultValue(): untyped =
  let prop = parseExpr("prop bi = 123")
  echo "Prop stmt: ", prop.treeRepr
  let parsed = parseProp(prop)
  let p = parsed.item
  assert(p.name.strVal == "bi")
  assert(p.type.isNone)
  assert(p.defaultValue.isSome)
  assert(p.defaultValue.get.kind == nnkIntLit)

testPropWithNameAndDefaultValue()

macro testAssignmentAndBinding(): untyped =
  let asgn = parseExpr("width <- 10")
  echo "Asgn: ", asgn.treeRepr

testAssignmentAndBinding()


macro testParsingComponent_1(): untyped =
  let nodes = parseExpr(
    """
Foo of Grid:
  prop bar: int = 123
  field baz: seq[int] = @[]

  let foo = "testing"

  width = 123

  discard x.subscribe(
    () => echo("Testing")
  )

  panel():
    rectangle()
"""
  )
  let comp = parseComponent(nodes)
  echo "Comp: ", comp.repr
  assert(comp.name.strVal == "Foo")
  assert(comp.parentComp.get.strVal == "Grid")

  assert(comp.props.len == 1)
  assert(comp.props[0].item.name.strVal == "bar")

  assert(comp.fields.len == 1)
  assert(comp.fields[0].item.name.strVal == "baz")

  assert(comp.assignments.len == 1)

  assert(comp.body.len == 2)

  assert(comp.children.len == 1)


testParsingComponent_1()
