## A non-standard format for generating more or less globally unique identifers.
## This module supports both C and JS targets, and maintains a consistent representation across them.

# TODO: Consider switching back to oids when https://github.com/nim-lang/Nim/pull/16203 makes its way into a release.

import random
import strutils
import strformat
import hashes
import times

type Guid* = object
  time*: int32    # Seconds since UNIX epoch
  count*: int32   # Value of incrementing counter
  random*: int32  # The spice of life

proc `$`*(guid: Guid): string =
  guid.time.toHex & guid.count.toHex & guid.random.toHex

const guidStringLength* = 2 * (3 * int32.sizeof)

proc parseGuid*(str: string): Guid =
  if str.len() != guidStringLength:
    let message = fmt"GUID strings must be exactly {guidStringLength} characters long, but '{str}' has length {str.len()}"
    raise newException(ValueError, message)
  Guid(
    time: fromHex[int32](str[0..<8]),
    count: fromHex[int32](str[8..<16]),
    random: fromHex[int32](str[16..<24])
  )

proc hash*(guid: Guid): Hash =
  !$(guid.time.hash() !& guid.count.hash() !& guid.random.hash())

type GuidGenerator* = object
  random*: Rand
  count*: int32

proc currentTimeSeed(): int64 =
  # Adapted from https://github.com/nim-lang/Nim/blob/3fb5157ab1b666a5a5c34efde0f357a82d433d04/lib/pure/random.nim#L627
  # For some reason, the standard library only implements this for the global PRNG
  when defined(js):
    int64(times.epochTime() * 1000) and 0x7fff_ffff
  else:
    let now = times.getTime()
    convert(Seconds, Nanoseconds, now.toUnix) + now.nanosecond

proc initRand(): Rand = initRand(currentTimeSeed())

proc initGuidGenerator*(): GuidGenerator = GuidGenerator(random: initRand(), count: 0)

proc genGuid*(gen: var GuidGenerator): Guid =
  let time = int32(getTime().toUnix() and high(int32))
  let random = int32(gen.random.rand(high(int32)))
  let count = gen.count
  gen.count += 1
  Guid(time:time, count:count, random:random)

var globalGenerator = initGuidGenerator()

proc genGuid*(): Guid =
  #TODO: Thread safety
  globalGenerator.genGuid()
