# Version 0 of AVM

Everything is in big-endian / network order

## Global header

|Offset|Length|Description|
|-|-|-|
|0x00|3 bytes|fixed `0x415656` magic value|
|0x03|1 byte|version number (corresponds to the version in this file name)|
|0x04|8 bytes|64-bit float for aspect ratio.<br /><br />- The sign bit references whether the video loops.<br />- The first bit in the exponent references whether we are calculating the `x` or `y`. If the bit is `0`, we are calculating `x` in terms of `y` (ex. `x=float*y`); if `1`, we are calculating `y` in terms of `x`. The number that is not being calculated is always equal to `1`.<br /><br />Before using the float, set the first two bits to `0` (`and` by `0x3FFFFFFFFFFFFFFF`).|
|0x0C|4 bytes|A 32-bit float indicating the theoretical max [color](#color) value we are using (e.g., `1` for SDR, `10` for HDR).|
|0x10|8 bytes|The number of [frame packets or number of header packets](#frame-packet) minus one, you always have to have atleast one frame packet|
|0x18|`16*header_packets_count` bytes (varies)|Implicit zero for the first 8 bytes for the first packet. And implicit zero for the 8 bytes after that. (If there is only one packet, so the number before this was zero, this field is not needed)<br /><br />- The first 8 bytes are an unsigned 64-bit number referencing the number of nanoseconds since the start of the video. (These need to be in ascending order (duplicates allowed); otherwise it is UB.)<br />- The second unsigned 64-bit number references the offset after the header for the first byte in the [frame packet](#frame-packet).|
|`0x18+0x10*header_packet_count`|varies|This is where the array of frame packets go|

## Frame Packet

The world is reset at the start of a frame packet (each packet is roughly an I frame + many P frames). By default the world has no object and the background is fully transparent.
Each frame packet is an array of [operations](#operation) with no other metadata.

All Frame Packets are compressed with LZMA, use the newest [lzma sdk](https://www.7-zip.org/sdk.html) version for compression for the highest ratios.

## Operation

|Offset|Length|Description|
|-|-|-|
|0x00|1 byte|[functions](#functions) to run|
|0x01|4 bytes|Number of nanoseconds to start running (from start of packet; always in ascending order, otherwise it is UB)|
|0x05|2 bytes|Unsigned 16-bit number of bytes in arguments|
|0x07|`number_of_bytes`|The arguments to the function|

Operations have a hard limit of doing anything ~4.29 seconds after the frame packet start.

Any time filters affect the same curve, the delta differences are added together, not multiplied or stacked. Multiple actions can run at the same nanosecond time, but the delta differences don't include any actions that start at that time.

It will run as follows:

- create item at 0ns
- stroke color red, `0.11` linear from 0 to 1 over 11ns starting at 0ns
- stroke color red, `0.6` linear from 0 to 1 over 6ns starting at 3ns
- stroke color red, `0.2` full set at 0ns starting at 5ns
- stroke color red, `0.1` full set at 0ns starting at 5ns

At 6ns the color would be `0.165` (`(0.2-(0.11/11*5 + (0.6-(0.11/11*3)/6)*2)) + (0.1-(0.11/11*5 + (0.6-(0.11/11*3)/6)*2))) + (0.11/11*6) + ((0.6-(0.11/11*3)/6)*3)`)

## Functions

- 0 - [create](#create)
- 1 - [delete](#delete)
- 2 - [move](#move)
- 3 - [stroke color](#stroke-color)
- 4 - [fill color](#fill-color)
- 5 - [stroke width](#stroke-width)
- 6 - [stroke gradient](#stroke-gradient)
- 7 - [fill gradient](#fill-gradient)
- 8 - [rotate](#rotate)
- 9 - [scale](#scale)

### Create

The arguments are an array of arrays of [world position](#world-position-16-bytes), each equaling an array of points for a Bézier curve. Each curve is joined so they touch end to end. `(0,0),(1,0),(1,1)|(0,1),(0,0)` means render two Bézier curves: `(0,0),(1,0),(1,1)` and `(1,1),(0,1),(0,0)`. Curves don't have to end at the same location, but we always make the ending point the starting point. The curve as a whole has an id that increments and starts at 0. [Ids](#id-4-bytes) are reset with each [frame packet](#frame-packet); the first curve you make has id 0, the second 1, etc.

Lines with 1 position are a point, 2 are a line, 3 are a curve, etc.

All new objects are created over all previous objects, so there is no way to edit z-index. Your curve [id](#id-4-bytes) is the z-index.

The array is delimited with `0x7FF0` or `0xFFF0`, so if the first 2 bytes of the [world position](#world-position-16-bytes) are that, shift over the window by 2 and continue reading. Having an array with nothing in it is UB. Using `0xFFF0` means that the edge should be rounded together so that you get a seamless line, `0x7FF0` means that it should just be 2 independent lines.

You can start or end a full curve with `0xFFF0` to mean that the end of the line be rounded off. If you start with one then the start of the line is rounded off, and if you end with one the end will be rounded off. If you round off, stroke color and gradiant will also be ended to go over the edge also.

### Delete

The arguments are an array of [ids](#id-4-bytes) that are deleted. Referencing them after this is UB.

### Move

|Offset|Length|Description|
|-|-|-|
|0x00|2 bytes|First bit is a flag for whether it affects `x`; second is for `y`. 2 bits reserved. The next 12 bits are the number of [Bézier positions](#bézier-position-12-bytes) minus one.|
|0x02|`(bézier_positions-1)*12+8` bytes (varies)|The first position has an implicit `0` for the `x`. Then it's an array of [Bézier position](#bézier-position-12-bytes).|
|`0x0A+(bézier_positions-1)*0x0C`|`operation_bytes-current_offset` bytes (varies)|This is a list of [ids](#id-4-bytes) that this operation affects.|

If both `x` and `y` is set, then both get effected by this.

### Stroke Color

|Offset|Length|Description|
|-|-|-|
|0x00|2 bytes|First bit flags whether the color affects red; next flags green, blue, then alpha. The next 12 bits are the number of [Bézier filter](#bézier-filter-12-bytes) minus one.|
|0x02|4-16 bytes (varies)|The [color](#color-16-bytes) that will be affected. If the bit for a channel is not set in the flag, those bytes are skipped. If the flag is `0110`, we would only have 8 bytes here: the first 4 for green, then 4 for blue.|
|0x02+(0x04 to 0x0F) (varies)|`(bézier_filters-1)*12+8` bytes (varies)|The first filter has an implicit `0` for the `x`. Then it's an array of [Bézier filter](#bézier-filter-12-bytes).|
|`0x0A+(bézier_filters-1)*0x0C+(0x04 to 0x0F)` (varies)|`operation_bytes-current_offset` bytes (varies)|This is a list of [ids](#id-4-bytes) that this operation affects.|

### Fill Color

|Offset|Length|Description|
|-|-|-|
|0x00|2 bytes|First bit flags whether the color affects red; next flags green, blue, then alpha. The next 12 bits are the number of [Bézier filter](#bézier-filter-12-bytes) minus one.|
|0x02|4-16 bytes (varies)|The [color](#color-16-bytes) that will be affected. If the bit for a channel is not set in the flag, those bytes are skipped. If the flag is `0110`, we would only have 8 bytes here: the first 4 for green, then 4 for blue.|
|0x02+(0x04 to 0x0F) (varies)|`(bézier_filters-1)*12+8` bytes (varies)|The first filter has an implicit `0` for the `x`. Then it's an array of [Bézier filter](#bézier-filter-12-bytes).|
|`0x0A+(bézier_filters-1)*0x0C+(0x04 to 0x0F)` (varies)|`operation_bytes-current_offset` bytes (varies)|This is a list of [ids](#id-4-bytes) that this operation affects.|

The fill location uses the `even-odd` rule to know when we are inside and when we are not.

### Stroke Width

|Offset|Length|Description|
|-|-|-|
|0x00|2 bytes|4 unreserved bits. The next 12 bits are the number of [Bézier filter](#bézier-filter-12-bytes) minus one.|
|0x02|8 bytes|The width of the stroke as a 64-bit float. `1` is half the screen, and `2` is the whole screen (it's the same length as the [x and y in positions](#world-position)). The width is how far out from the line it goes. Negative is UB.|
|0x0A|`(bézier_filters-1)*12+8` bytes (varies)|The first filter has an implicit `0` for the `x`. Then it's an array of [Bézier filter](#bézier-filter-12-bytes).|
|`0x12+(bézier_filters-1)*0x0C` (varies)|`operation_bytes-current_offset` bytes (varies)|This is a list of [ids](#id-4-bytes) that this operation affects.|

### Stroke Gradient

|Offset|Length|Description|
|-|-|-|
|0x00|2 bytes|First bit flags whether the color affects red; next flags green, blue, then alpha. The next 12 bits are the number of [Bézier fines](#bézier-fine-16-bytes) minus one.|
|0x02|4-16 bytes (varies)|The [color](#color-16-bytes) that will be affected. If the bit for a channel is not set in the flag, those bytes are skipped. If the flag is `0110`, we would only have 8 bytes here: the first 4 for green, then 4 for blue.|
|0x02+(0x04 to 0x10) (varies)|`bézier_fines*16` bytes (varies)|An array of [Bézier fine](#bézier-fine-16-bytes). The `x` indicates how far away from the stroke we are: `0` is at the stroke, and `1` is at the stroke width away.|
|`0x02+bézier_fines*0x10+(0x04 to 0x0F)` (varies)|`operation_bytes-current_offset` bytes (varies)|This is a list of [ids](#id-4-bytes) that this operation affects.|

The default stroke width is `0`.

### Fill Gradient

|Offset|Length|Description|
|-|-|-|
|0x00|2 bytes|First bit flags whether the color affects red; next flags green, blue, then alpha. The next 12 bits are the number of [Bézier fines](#bézier-fine-16-bytes) minus one.|
|0x02|16 bytes|This is a [world position](#world-position-16-bytes) that is where the gradient is from. The gradient direction and source are attributes of the items, so any modifications to the curves also affect this (e.g., move, rotate, scale). For directional gradients, have at least the `x` or `y` equal to infinity (`NaN` is UB). The angle between the non-infinity value and `(0,0)` gives a value between `0` and `pi/2`; the infinity value determines which 45° rotated quadrant we are in. For example, if x is negative infinity and y is 1, the radian value is `3pi/4`. If y is negative infinity and x is `-0.5`, that gives `7pi/4`. Take the non-infinity value and multiply it by `pi/4`; for `x==infinity` add 0, `y==infinity` add `pi/2`, `x==-infinity` add `pi`, and `y==-infinity` add `3pi/2`.|
|0x12|4-16 bytes (varies)|The [color](#color-16-bytes) that will be affected. If the bit for a channel is not set in the flag, those bytes are skipped. If the flag is `0110`, we would only have 8 bytes here: the first 4 for green, then 4 for blue.|
|0x12+(0x04 to 0x18) (varies)|`bézier_fines*16` bytes (varies)|An array of [Bézier fine](#bézier-fine-16-bytes). The `x` indicates how far away from the source we are: `0` is at the stroke, and `1` is at the stroke width away. For directional points it is based on distance from the closest point of the tangent point on the circle with radius sqrt(2) around the viewing plane, from the farthest point from the radian location. (For example, with an angle of `pi/4` (~0.7854), the distance is how far the point is from `y=-x-2`, or `y=tan(r+pi/2)(x+cos(r)*sqrt(2))-sin(r)*sqrt(2)`.)|
|`0x12+bézier_fines*0x10+(0x04 to 0x0F)` (varies)|`operation_bytes-current_offset` bytes (varies)|This is a list of [ids](#id-4-bytes) that this operation affects.|

### Rotate

|Offset|Length|Description|
|-|-|-|
|0x00|2 bytes|4 unused bits. The next 12 bits are the number of [Bézier filters](#bézier-filter-12-bytes) minus one.|
|0x02|16 bytes|This is a [world position](#world-position-16-bytes) that is the rotation origin. The rotation location is not an attribute of the items.|
|0x12|`(bézier_filters-1)*12+8` bytes (varies)|The first filter has an implicit `0` for the `x`. Then it's an array of [Bézier filter](#bézier-filter-12-bytes). The y value is how many radians to rotate by. If it is `pi/2`, that means rotate by `-90 degrees clockwise`; `3pi/2` or `-pi/2` means rotate by `90 degrees clockwise`.|
|`0x1A+(bézier_filters-1)*0xC` (varies)|`operation_bytes-current_offset` bytes (varies)|This is a list of [ids](#id-4-bytes) that this operation affects.|

Addative rotation works by taking the delta of the point locations before and after the rotation and adding them together.

### Scale

|Offset|Length|Description|
|-|-|-|
|0x00|2 bytes|4 unused bits. The next 12 bits are the number of [Bézier filters](#bézier-filter-12-bytes) minus one.|
|0x02|16 bytes|This is a [world position](#world-position-16-bytes) that is the scale origin. The scale location is not an attribute of the items.|
|0x12|`(bézier_filters-1)*12+8` bytes (varies)|The first filter has an implicit `0` for the `x`. Then it's an array of [Bézier filter](#bézier-filter-12-bytes). The y value is the scale set on the object: `1` means no change, `2` means twice as big, and `1/2` means half the size.|
|`0x1A+(bézier_filters-1)*0xC` (varies)|`operation_bytes-current_offset` bytes (varies)|This is a list of [ids](#id-4-bytes) that this operation affects.|

Addative scaling works by taking the delta of the point locations before and after the scales and adding them together.

## Definitions

### World Position (16 bytes)

For positions we always have two 64-bit floats: the first is `x`, the second is `y`. `[-1,-1]` is the top-left and `[1,1]` is the bottom-right. Other values are off-screen.

If the aspect ratio has `x` in terms of `y`, and a value of `0.5`, and a y size of `500px`, the size is `(250,500)`. If we take `(0,0)` as the top-left and `(250,500)` as the bottom-right, all ratios remain as if this were a square. `[0,0]` then means `(125,250)`; it scales to the aspect ratio at runtime.

### Bézier Position (12 bytes)

For the Bézier position, the first 4 bytes are an unsigned 32-bit number referencing the nanosecond offset to use (if in a [function](#functions), that usually means the offset from when the function was run). If the `function offset` + `position offset` is larger than what an unsigned 32-bit number can handle, that is UB.

The next 8 bytes are defined the same way as the `y` in the [world position](world-position-16-bytes).

### Bézier Filter (12 bytes)

Same as [Bézier position](#bézier-position-12-bytes) but the `y` is now how much of the new value to use: `1` means add the new value, and `0` means don't add anything. Any number is valid; you can have a negative y, but if values overflow that is UB. After the curve finishes, the ending value is used going forward. The first time the filter appears in an array it has an implicit `0` for the `x`, so setting `y` to `1` immediately switches to that value.

### Bézier Fine (16 bytes)

Same as [Bézier filter](#bézier-position-12-bytes) but the `x` is a 64-bit float. The `x` should be between `0` and `1`; anything else is UB.

### Color (16 bytes)

Colors are RGBA, represented as 32-bit floats each. `[0,1]` range means SDR colors, with `1` meaning `100` nits and `10` meaning `1000` nits. Multiply the value by `100` to get nits. For alpha, the range is `[0,1]`, where `0` is fully transparent and `1` is opaque. Using the sign bit is UB.

By default, all objects (including the background) have the value `(0.0,0.0,0.0,0.0)`.

### Id (4 bytes)

Ids are an unsigned 32-bit number that automatically increments and never decreases.
