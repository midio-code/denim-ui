# Denim UI

A custom cross platform UI framework focused on fast and easy prototyping by the use of a custom DSL.

The various platforms are supported through separate backend implementations. An js backend that uses the canvas api for drawing and html for native components the only somewhat usable backend, but a native one is planned.

## Minimal example

![minimal](minimal_example.png)

```nim
import denim_ui
import denim_ui_canvas

proc render(): Element =
  panel:
    rectangle(
      color = colCadetBlue,
      radius = (10.0, 2.0, 10.0, 2.0),
      width = 150,
      height = 60,
      alignment = Alignment.Center
    )
    text(
      text = "Hello world!",
      fontSize = 14.0,
      color = colWhite,
      alignment = Alignment.Center
    )

startApp(
  render,
  "rootCanvas",
  "nativeContainer"
)
```


```html
<html lang="en">
	<body>
		<div id="nativeContainer">
			<canvas id="rootCanvas"></canvas>
		</div>
	</body>
	<!-- the bundle output by nim -->
	<script type="text/javascript" src="./dist/bundle.js"></script>
</html>
```


# DSL

Denim has a neat custom DSL for writing UIs. It allows one to easily create deep UI trees, as well as group parts of the UI into reusable components.

```nim
component MyButton(
  label: string,
  clicked: () -> void
):
  let isHovering = behaviorSubject(false)

  alignment = Alignment.Center

  rectangle(
    color <- isHovering.source.choose(colHotPink, colForestGreen)
  )
  text(
    text <- isHovering.source.choose("hovering", label),
    margin = thickness(10.0),
    color = colWhite
  )

  toggleOnHover(
    isHovering <- not isHovering.value
  )

  onClicked(
    proc(e: Element, args: PointerArgs, res: var EventResult) =
      if not isNil(clicked):
        # NOTE: Due to a quirk in the DSL, function props
        # needs to be surrounded with () before being called
        (clicked)()
  )

proc render*(): Element =
  myButton(
    label = "Hello!",
    clicked = proc() =
      echo "Button clicked"
  )
```

# The Element type

All the visual nodes in the UI tree inherit from the Element type.

`panel()`, for example, creates an element with the layout semantics of a panel (we'll get to layout soon).

## Attributes available on all element types:

- width: `Option[float]`
- height: `Option[float]`
- maxWidth: `Option[float]`
- minWidth: `Option[float]`
- maxHeight: `Option[float]`
- minHeight: `Option[float]`
- x: `Option[float]` The elements X-position in its parent
- y: `Option[float]` The elements Y-position in its parent
- xOffset: `Option[float]` An offset added to the X-position of the element after it has been arranged by its parent
- yOffset: `Option[float]` An offset added to the Y-position of the element after it has been arranged by its parent
- margin: `Option[Thickness[float]]`
- alignment: `Option[Alignment]`
- visibility: `Option[Visibility]`
- clipToBounds: `Option[bool]`
- transform: `seq[Transform]` A list of transforms added in order to the element after it has been arranged by its parent
- zIndex: `Option[int]` An index allowing an item to be drawn on top or below of its siblings. The higher the index, the more on top it is drawn.
- shadow: `Option[Shadow]`

!!! note "Note about all the options"
	Denim exports a converter from any type to Option, so you don't have to explicitly wrap all attribute values in an option:
	`converter toOption*[T](x: T): Option[T] = some[T](x)`. It has proven quite convenient when writing UI code, but can sometimes get in the way, as generic converters often tend to do.
	We would like to remove this converter and get the DSL to handle the conversion instead in the future.


### Alignment

```nim
Alignment = enum
  Stretch, Left, TopLeft, Top, TopRight, Right,
  BottomRight, Bottom, BottomLeft, Center,
  CenterLeft, CenterRight, TopCenter, BottomCenter,
  HorizontalCenter, VerticalCenter
```

### Visibility
```nim
Visibility = enum
  Visible, Collapsed, Hidden
```

## Layout

Layout is created using a set of elements that lays out its children in various ways.

### Panel

Panel performs the default layout on the children, where all children get all available space. The children of a panel will by default fill their entire space. If a panel contains several children, it simply layers them on top of each other.

### Dock

Lays out its children by docking them to the various sides, one after the other.

```nim
dock:
  dockLeft:
    rectangle(width = 10, height = 10, color = colRed)
  dockTop:
    rectangle(width = 10, height = 10, color = colBlue)
  rectangle(width = 10, height = 10, color = colYellow)
```

The last child element fills the remaining space.

### Stack

Stacks its children vertically by default. One can set the `direction` attribute to stack horizontally.

```nim
stack(direction = StackDirection.Horizontal):
  rectangle(width = 10, height = 10, color = colRed)
  rectangle(width = 10, height = 10, color = colBlue)
  rectangle(width = 10, height = 10, color = colYellow)
```

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
