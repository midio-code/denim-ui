import options, sets, sequtils, sugar
import ../types
import ../element
import ../data_binding
import rx_nim
import ../../guid
import ../../utils

proc bindChildCollection*(self: Element, item: Subject[Element]): void =
  var prevElem: Element
  self.subscribe(
    item.source,
    proc(e: Element): void =
      if not isNil(prevElem):
        self.removeChild(prevElem)
      prevElem = e
      if not isNil(e):
        self.addChild(e)
  )

proc bindChildCollection*(self: Element, item: Observable[Option[Element]]): void =
  var prevElem: Element
  self.subscribe(
    item,
    proc(e: Option[Element]): void =
      if not isNil(prevElem):
        self.removeChild(prevElem)
      if e.isSome():
        prevElem = e.get()
        self.addChild(e.get())
  )

proc bindChildCollection*(self: Element, item: Observable[Element]): void =
  var prevElem: Element
  self.subscribe(
    item,
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

  var elementsManagedByThisBinding = newSeq[Guid]()
  self.subscribe(
    subj.source,
    proc(newVal: seq[Element]): void =
      var toRemoveFromManagementList: seq[Guid] = @[]
      # Delete items which we manage, but which are
      # not in this version of the clist.
      for id in elementsManagedByThisBinding:
        let capturedId = id # NOTE: Need a variable here to not violate memory safety (as reported by the compiler)
        if not newVal.any((x) => x.id == capturedId):
          var toRemove: seq[Element] = @[]
          for child in self.children:
            if child.id == id:
              toRemove.add(child)
          for child in toRemove:
            self.removeChild(child)

          toRemoveFromManagementList.add(id)
      # Remove the items we are no longer managing
      for id in toRemoveFromManagementList:
        elementsManagedByThisBinding.delete(elementsManagedByThisBinding.find(id))

      # Add the new elements
      for elem in newVal:
        let elemId = elem.id
        if not self.children.any((x) => x.id == elemId):
          elementsManagedByThisBinding.add(elemId)
          self.addChild(elem)
    )

proc bindChildCollection*(self: Element, obs: Observable[seq[Element]]): void =
  let subj = behaviorSubject(obs)
  self.bindChildCollection(subj)

proc bindChildCollection*(self: Element, obs: ObservableCollection[Element]): void =
  self.subscribe(
    obs,
    proc(change: Change[Element]): void =
      case change.kind:
        of ChangeKind.Added:
          self.insertChild(change.newItem, change.addedAtIndex)
        of ChangeKind.Removed:
          self.removeChild(change.removedItem)
        of ChangeKind.Changed:
          self.removeChild(change.oldVal)
          self.addChild(change.newVal)
        of ChangeKind.InitialItems:
          for i in change.items:
            self.addChild(i)
  )

template bindChildCollection*(self: Element, subj: CollectionSubject[Element]): void =
  self.bindChildCollection(subj.source)

