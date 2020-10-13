
# ... StmtList
# ...   TypeSection
# ...     TypeDef
# ...       Ident "Test"
# ...       Empty
# ...       ObjectTy
# ...         Empty
# ...         Empty
# ...         RecList
# ...           IdentDefs
# ...             Ident "foo"
# ...             Ident "float"
# ...             Empty
# ...           IdentDefs
# ...             Ident "bar"
# ...             Ident "string"
# ...             Empty

# dumpAstGen:
#   proc foo(): void =
#     echo "hei"

# macro partial(typeDeclaration, members: untyped): untyped =

#   echo typeDeclaration.treeRepr
#   let recList = nnkRecList.newTree()
#   for member in members:
#     recList.add nnkIdentDefs.newTree(
#       newIdentNode(member[0].strVal()),
#       nnkBracketExpr.newTree(
#         newIdentNode("Option"),
#         newIdentNode(member[1][0].strVal()),
#       ),
#       newEmptyNode()
#     )
#   result = nnkStmtList.newTree(
#     nnkTypeSection.newTree(
#       nnkTypeDef.newTree(
#         newIdentNode(typeDeclaration.strVal()),
#         newEmptyNode(),
#         nnkObjectTy.newTree(
#           newEmptyNode(),
#           newEmptyNode(),
#           recList
#         )
#       )
#     )
#   )

#   let typeName = typeDeclaration.strVal()
#   result.add nnkProcDef.newTree(
#     newIdentNode("foo"),
#     newEmptyNode(),
#     newEmptyNode(),
#     nnkFormalParams.newTree(
#       newIdentNode("void")
#     ),
#     newEmptyNode(),
#     newEmptyNode(),
#     nnkStmtList.newTree(
#       nnkCommand.newTree(
#         newIdentNode("echo"),
#         newLit("hei")
#       )
#     )
#   )

# expandMacros:
#   partial(Test):
#     foo: float
#     bar: string
