when not defined(js):
  import oids
  export oids

when not defined(js):
  type
    Guid* = Oid
else:
  type
    Guid* = int


when not defined(js):
  proc genGuid*(): Guid =
    genOid()
else:
  var counter = 1
  proc genGuid*(): Guid =
    result = counter
    counter += 1
