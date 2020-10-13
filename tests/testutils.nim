template root*(elem: untyped): untyped =
  block:
    let ret = elem
    ret.addTag("root")
    ret
