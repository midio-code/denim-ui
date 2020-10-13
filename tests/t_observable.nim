import sugar
import unittest
import midio_ui

suite "observable tests":
  test "Observable test 1":
    let subj = behaviorSubject(123)
    var test = 0
    discard subj.subscribe((val: int) => (test = val))
    check(test == 123)
    subj.next(321)
    check(test == 321)
    discard subj.subscribe((val: int) => (test = 555))
    check(test == 555)

  test "Map operator":
    let subj = behaviorSubject[int](2)
    let mapped = subj.source.map(
      proc(x: int): int =
        x * x
    )
    var val = 0
    discard mapped.subscribe(
      proc(newVal: int): void =
        val = newVal
    )
    check(val == 4)
    subj.next(9)
    check(val == 81)

  test "Two maps":
    let subj = behaviorSubject[int](2)
    let first = subj.source.map(
      proc(x: int): int =
        x * x
    )
    let second = first.map(
      proc(x: int): int =
        x * 10
    )
    var res = 0
    discard second.subscribe(
      proc(y: int): void =
        res = y
    )
    check(res == 40)

  test "Combine latest":
    let s1 = behaviorSubject(5)
    let s2 = behaviorSubject(10)
    let combined = s1.combineLatest(s2, (a,b) => (a + b))
    var res = 0
    discard combined.subscribe((newVal: int) => (res = newVal))
    check(res == 15)

  test "Subject wrapping observable":
    let subj1 = behaviorSubject(10)
    let m1 = subj1.map((x: int) => x * x)
    let subj2 = behaviorSubject(m1)
    check(subj2.value == 100)
    subj1.next(5)
    check(subj2.value == 25)

  test "Subscription test":
    let s = behaviorSubject(10)
    var subscriptionCalls = 0
    discard s.source.subscribe(
      proc(x: int): void =
        subscriptionCalls += 1
    )
    check(subscriptionCalls == 1)
    discard s.source.subscribe(
      proc(x: int): void =
        subscriptionCalls += 1
    )
    check(subscriptionCalls == 2)
    s.next(123)
    check(subscriptionCalls == 4)

  test "Completing observable":
    let obs = create(@[1,2,3,4,5])
    var value = 0
    var completed = false
    discard obs.subscribe(
      proc(val: int) = value += val,
      proc() = completed = true
    )

    check(value == 1+2+3+4+5)
    check(completed == true)

  test "Completing subject":
    let subj = behaviorSubject(1)
    subj.next(2)
    check(subj.value == 2)
    subj.complete()

    expect(Exception):
      subj.next(3)

  test "Observable then":
    let a = create(@[1,3,5])
    let b = create(@[2,4,6])

    let combined = a.then(b)

    var sum = 0
    var completed = 0
    discard combined.subscribe(
      proc(val: int) =
        sum += val
        check(completed == 0)
      ,
      proc() = completed += 1
    )
    check(sum == 1+2+3+4+5+6)
    check(completed == 1)


suite "observable collection tests":
  test "Added and removed notifications":
    let collection = observableCollection[int](@[])
    var total = 0
    collection.source(
      proc(item: int): void =
        total += item
      ,
      proc(item: int): void =
        total -= item
    )
    check(total == 0)
    collection.add(10)
    check(total == 10)
    collection.add(5)
    check(total == 15)
    collection.remove(10)
    check(total == 5)

  test "Mapping observable collection":
    let collection = observableCollection[int](@[])
    var total = 0
    collection.source(
      proc(item: int): void =
        total += item
      ,
      proc(item: int): void =
        total -= item
    )
    var mapped = 0
    let mappedCollection = collection.source.map(
      proc(x: int): int =
        x * 2
    )
    mappedCollection(
      proc(item: int): void =
        mapped += item
      ,
      proc(item: int): void =
        mapped -= item
    )

    check(total == 0)
    check(mapped == 0)
    collection.add(10)
    check(total == 10)
    check(mapped == 20)
    collection.add(5)
    check(total == 15)
    check(mapped == 30)
    collection.remove(10)
    check(total == 5)
    check(mapped == 10)

  test "Another mapping observable collection":
    let collection = observableCollection[int](@[])
    var total = 0
    var a = 0
    var b = 0
    let mappedCollection = collection.source.map(
      proc(x: int): int =
        echo "Mapping"
        total += 1
        x
    )
    mappedCollection(
      proc(item: int): void =
        a += 1
      ,
      proc(item: int): void =
        a -= 1
    )
    mappedCollection(
      proc(item: int): void =
        b += 1
      ,
      proc(item: int): void =
        b -= 1
    )
    collection.add(1)
    collection.add(2)
    collection.add(3)
    collection.add(4)

    check(total == 4)
    check(a == 4)
    check(b == 4)

  test "Subject (PublishSubject) basics":
    let subj = subject[int]()
    var ret = 123
    subj.next(111)
    check(ret == 123)
    discard subj.source.subscribe(
      proc(val: int): void =
        ret = val
    )
    check(ret == 123)
    subj.next(321)
    check(ret == 321)

  test "Merge":
    let outer = subject[Observable[int]]()

    let merged = outer.merge()

    var total = 0
    discard merged.subscribe(
      proc(val: int): void =
        total += val
    )

    let value = behaviorSubject(merged)
    check(value.value == 0)
    check(total == 0)

    let s1 = behaviorSubject(10)
    outer.next(
      s1.source
    )

    check(value.value == 10)
    check(total == 10)

    s1.next(5)
    check(value.value == 5)
    check(total == 15)


    let s2 = behaviorSubject(4)
    outer.next(
      s2.source
    )
    check(value.value == 4)
    check(total == 19)

    s1.next(1)
    check(value.value == 1)
    check(total == 20)

  test "Switch":
    let outer = subject[Observable[int]]()

    let switched = outer.switch()

    var total = 0
    discard switched.subscribe(
      proc(val: int): void =
        total += val
    )

    let value = behaviorSubject(switched)
    check(value.value == 0)
    check(total == 0)

    let s1 = behaviorSubject(10)
    outer.next(
      s1.source
    )

    check(value.value == 10)
    check(total == 10)

    s1.next(5)
    check(value.value == 5)
    check(total == 15)


    let s2 = behaviorSubject(4)
    outer.next(
      s2.source
    )
    check(value.value == 4)
    check(total == 19)

    s1.next(1)
    check(value.value == 4)
    check(total == 19)
