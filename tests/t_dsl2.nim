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
  assert(parsed.name.strVal == "bi")
  assert(parsed.type.isSome)
  assert(parsed.type.get.kind == nnkIdent)
  assert(parsed.defaultValue.isNone)

testPropWithNameAndType()

macro testPropWithNameAndTypeAndDefaultValue(): untyped =
  let prop = parseExpr("prop bi: int = 123")
  echo "Prop stmt: ", prop.treeRepr
  let parsed = parseProp(prop)
  assert(parsed.name.strVal == "bi")
  assert(parsed.type.isSome)
  assert(parsed.type.get.kind == nnkIdent)
  assert(parsed.defaultValue.isSome)
  assert(parsed.defaultValue.get.kind == nnkIntLit)

testPropWithNameAndTypeAndDefaultValue()

macro testPropWithNameAndDefaultValue(): untyped =
  let prop = parseExpr("prop bi = 123")
  echo "Prop stmt: ", prop.treeRepr
  let parsed = parseProp(prop)
  assert(parsed.name.strVal == "bi")
  assert(parsed.type.isNone)
  assert(parsed.defaultValue.isSome)
  assert(parsed.defaultValue.get.kind == nnkIntLit)

testPropWithNameAndDefaultValue()
