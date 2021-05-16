import options
import ../types
import ../element
import ../dsl/dsl
import ../drawing_primitives
import ../world_position
import ../../type_name

type
  ImageProps* = ref object
    uri*: string

  Image* = ref object of Element
    imageProps*: ImageProps

implTypeName(Image)

method render(self: Image): Option[Primitive] =
  let props = self.imageProps
  let worldPos = self.actualWorldPosition()
  some(
    self.image(
      props.uri
    )
  )

proc createImage*(props: (ElementProps, ImageProps)): Image =
  result = Image(
    imageProps: props[1]
  )
  initElement(result, props[0])


element_type(image, (ElementProps, ImageProps), createImage)
