import options, sets, sequtils, sugar
import ../types
import ../element
import rx_nim
import ../../guid
import ../../utils

proc bindChildCollection*(self: Element, item: Subject[Element]): void =
  var prevElem: Element
  ## TODO: handle subscription
  discard item.subscribe(
    proc(e: Element): void =
      if not isNil(prevElem):
        self.removeChild(prevElem)
      prevElem = e
      self.addChild(e)
  )

proc bindChildCollection*(self: Element, item: Observable[Option[Element]]): void =
  var prevElem: Element
  ## TODO: handle subscription
  discard item.subscribe(
    proc(e: Option[Element]): void =
      if not isNil(prevElem):
        self.removeChild(prevElem)
      if e.isSome():
        prevElem = e.get()
        self.addChild(e.get())
  )

proc bindChildCollection*(self: Element, item: Observable[Element]): void =
  var prevElem: Element
  ## TODO: handle subscription
  discard item.subscribe(
    proc(e: Element): void =
      if not isNil(prevElem):
        self.removeChild(prevElem)
      prevElem = e
      self.addChild(e)
  )

template bindChildCollection*(self: Element, item: Subject[Option[Element]]): void =
  bindChildCollection(self, item.source)

proc bindChildCollection*(self: Element, items: seq[Element]): void =
  for item in items:
    self.addChild(item)

proc bindChildCollection*(self: Element, subj: Subject[seq[Element]]): void =
  ## TODO: Keep the correct ordering of the children even with multiple child lists spread

  var elementsManagedByThisBinding = initHashSet[Guid]()
  ## TODO: Dispose of collection subscription !!!!!!!!
  discard subj.subscribe(
    proc(newVal: seq[Element]): void =
      var toRemoveFromManagementList: seq[Guid] = @[]
      # Delete items which we manage, but which are
      # not in this version of the clist.
      for id in elementsManagedByThisBinding:
        if not newVal.any((x) => x.id == id):
          self.children.deleteWhere((x) => x.id == id)
          toRemoveFromManagementList.add(id)
      # Remove the items we are no longer managing
      for id in toRemoveFromManagementList:
        elementsManagedByThisBinding.excl(id)


      # Add the new elements
      for elem in newVal:
        let elemId = elem.id
        if not self.children.any((x) => x.id == elemId):
          elementsManagedByThisBinding.incl(elemId)
          self.addChild(elem)
    )

proc bindChildCollection*(self: Element, obs: Observable[seq[Element]]): void =
  ## TODO: If we are to bind an Observable of seq[Element], we need a way for the binding
  ## we make here to be able to only add the elements that are new, and remove those that are not there
  ## any more.
  ## The problem is that the child collection also has children that are not 'managed' by this observable
  ## and so, we need to not interfer with them!
  let subj = behaviorSubject(obs)
  self.bindChildCollection(subj)


proc bindChildCollection*(self: Element, subj: CollectionSubject[Element]): void =
  for child in subj.values:
    self.addChild(child)
  # TODO: Handle subscriptions for bound child collections
  discard subj.subscribe(
    proc(added: Element): void =
      self.addChild(added),
    proc(removed: Element): void =
      self.removeChild(removed)
  )
