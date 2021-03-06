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
