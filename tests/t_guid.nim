import unittest
import sets

import denim_ui/guid

suite "Guid":
  test "It does not generate the same Guid twice in a row":
    let g1 = genGuid()
    let g2 = genGuid()
    check(g1 != g2)
  
  test "It survives a round-trip to a string":
    let guid = genGuid()
    check(guid == parseGuid($guid))

  test "It can be found in a hash set along with some friends":
    let guid = genGuid()
    let s = toHashSet([guid, genGuid(), genGuid(), genGuid(), genGuid()])
    check(guid in s)

  test "It raises a ValueError when attempting to parse a Guid of incorrect length":
    expect ValueError:
      discard parseGuid("123")
  
  test "It raises a ValueError when attempting to parse a Guid that contains non-hexadecimal characters":
    let str = "this is not hexadecimal!"
    check(str.len() == guidStringLength) # Rule out ValueError due to incorrect length in test string
    expect ValueError:
      discard parseGuid(str)
  
  test "It parses a Guid consisting of all zeroes":
    let guid = parseGuid("000000000000000000000000")
    let zero = Guid(time: 0, count: 0, random: 0)
    check(guid == zero)
  
  test "It parses a Guid with mixed lower- and upper-case hexadecimal characters":
    discard parseGuid("abcdefABCDEFaAbBcCdDeEfF")
