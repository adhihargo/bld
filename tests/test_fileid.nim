include fileid

import std/unittest

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

proc main() =
  let
    fileList =
      @[
        "a.blend", "b.blend1", "c.exe", "d.blend2",
        r"Q:\library\cg_library\GREASE_PENCIL\Samples\(Volumetric Still) Wolf-x2 by Kristian Emil.blend",
        r"Q:\library\cg_library\SHADER_BLENDER\Adriano D'Elia\3dprint_shader.blend",
        r"Q:\library\cg_library\OBJECT\Alberto Petronio - Gunship\Gunship_Artstation.blend",
        r"C:\prog\blender\stable\blender-4.2.17-lts.76b996a81c95\blender.exe",
        r"C:\prog\blender-2.92_Parallax-Occlusion-Mapping\blender-2.92.0-git.7f0cdf968810-windows64\blender.exe",
        r"S:\sketch\nature_15.kra",
      ]
    blendList = getArgsBlendList(fileList)
    exeList = getArgsExeList(fileList)
  echo "blendList: ", blendList
  echo "exeList: ", exeList
  echo ""

  let confData = readConfigFiles()
  if confData == nil:
    quit(QuitFailure)

  let versionTable = getBlenderFileVersionTable(blendList, confData)
  for fp, fv in versionTable.pairs:
    echo "FILE: ", fp, ": ", fv

  for exePath in exeList:
    echo "getBlenderExeVersionTable(exePath): ", getBlenderExeVersionTable(@[exePath])
    echo "exePath: ", exePath
    echo " "

when isMainModule:
  # discard
  main()
