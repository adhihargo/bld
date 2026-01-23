import std/options
import std/tables
import std/unittest

import fileid
import config

test "Parse .blend file name":
  check isBlendFileName("test.blend")

test "Parse backup .blend file name":
  check isBlendFileName("test a b c.blend1")

test "Parse Blender version string":
  let exeVersion = readExeVersionLine("Blender 2.49 Beta")
  check exeVersion.isSome and exeVersion.get() == "2.49 Beta"

test "Parse old Blender version string":
  let ovt = readVersionTriplet("2.49")
  check ovt.isSome() and (
    let vt = ovt.get
    vt[0] == 2 and vt[1] == 49
  )

test "Parse new Blender version string":
  let ovt = readVersionTriplet("5.0.1 SomethingElse")
  check ovt.isSome() and (
    let vt = ovt.get
    vt[0] == 5 and vt[1] == 0 and vt[2] == 1
  )
