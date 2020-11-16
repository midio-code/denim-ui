# Not ready for use

This project is still in pre-alpha, and should currenly not be used for anything other than playing around.

# Midio UI framework

A custom cross platform UI framework focused on fast and easy prototyping by the use of a custom DSL.

# Reference docs

https://nortero-code.github.io/midio-ui/

# DSL

The syntax for creating GUIs using the DSL is as follows:

```nim
elemType(attribute1 = value1, attribute2 = value2):
  child1(attrib1 ...
  ...
```

The basic type is the Element type, which is what the entire GUI is created from.

`panel()`, for example, creates an element with the layout semantics of a panel.

## Attributes available to all element types:

```nim
  Alignment* {.pure.} = enum
    Stretch, Left, TopLeft, Top, TopRight, Right,
    BottomRight, Bottom, BottomLeft, Center,
    CenterLeft, CenterRight, TopCenter, BottomCenter,
    HorizontalCenter, VerticalCenter

  Visibility* {.pure.} = enum
    Visible, Collapsed, Hidden
```
```nim
width*: Option[float]
height*: Option[float]
maxWidth*: Option[float]
minWidth*: Option[float]
maxHeight*: Option[float]
minHeight*: Option[float]
x*: Option[float]
y*: Option[float]
xOffset*: Option[float]
yOffset*: Option[float]
margin*: Option[Thickness[float]]
alignment*: Option[Alignment]
visibility*: Option[Visibility]
clipToBounds*: Option[bool]
# TODO: Implement all transforms for all rendering backends
transform*: Option[Transform]
```

## Layout primitives

### All elements

TODO

### Panel

TODO

### Dock

TODO

### Stack

TODO

### Grid (TODO)

TODO

## Visual primitives

TODO

### Rectangle

TODO

### Circle

TODO

### Text

TODO

### Path

TODO

## Behaviors

TODO

### onClick

TODO

### onPressed

TODO

### onReleased

TODO

### onPointerMoved

TODO

### onDrag

TODO

## Data binding

For dynamic data, we use the Observable pattern, which works pretty much as RX observables (http://reactivex.io/intro.html), sans some missing operators.

We can bind observables to attributes using the `<-` operator:

```nim
let widthValue = behaviorSubject(100.0)
panel(width <- widthValue)
```

We can also have dynamic children using the spread operator ...:

```nim
let someChildren = observableCollection(@[panel(), text(), rectangle()])
panel:
  ...someChildren
```

Note that the spread operator currently works for the following types:
- `seq[Element]`
- `Subject[Element]`
- `Subject[Option[Element]]`
- `Subject[seq[Element]]`
- `Observable[Element]`
- `CollectionSubject[Element]`

More can be supported by simply creating a `proc` with the following signature:

```nim
proc bindChildCollection*(self: Element, items: THE_TYPE_TO_SUPPORT): void =
   ...
```

This proc should set up the necessary subscriptions that manipulate the elements children using `addChild` and `removeChild`.

Here is an example of how the implementation for `Subject[Element]` works:

```nim
proc bindChildCollection*(self: Element, item: Subject[Element]): void =
  var prevElem: Element
  discard item.subscribe(
    proc(e: Element): void =
      if not isNil(prevElem):
        self.removeChild(prevElem)
      prevElem = e
      self.addChild(e)
  )
```

## Components

Components lets us create reusable element types more easily, and can be defined like so:

```nim
component ComponentName(prop1: AttrType1, prop2: AttrType2):
  let foo = "bar"

  panel:
    text(text = foo)
```

Component bodies can contain whatever code (almost) you want, as long as it return an element.

The component can then be used with the DSL syntax like any other element:

```nim
panel:
  componentName(prop1 = ....
```

NOTE: Components should be named with an upper case first letter, but are instantiated with lower case.

### Component fields

One can add fields to a component using the field keyword:

```nim
component Foo():
  field myField: float
  ...
```

This field can the be accessed from the instantiating scope:

```nim
let f = Foo()
echo foo.myField
```

This is useful if one wants to expose certain parts of a component to the outside.

### NOTE: Databinding doesn't work for component properties

Since the properties are just passed by value as parameters to the component body,
if you want property values of component children to be changed dynamically, they need to be passed as Observables:

```nim
component MyDynamicComp(val1: Observabie[float]):
  panel(width <- val1)
```
