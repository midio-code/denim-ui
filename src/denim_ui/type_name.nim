import macros

# TODO: Consider implementing this for specific base types only,
#       as this adds bloat to the vtable of every RootObj.
method typeName*(self: RootObj): string {.base.} = "RootObj"

macro implTypeName*(ty: typedesc): untyped =
  ty.expectKind(nnkSym)
  let typeNameLit = ty.strVal.newStrLitNode
  quote do:
    method typeName*(self: `ty`): string = `typeNameLit`
