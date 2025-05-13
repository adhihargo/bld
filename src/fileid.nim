import std/nre
import std/os
import std/osproc
import std/options
import std/re
import std/sequtils

let
  BLEND_RE = re.re"\.blend\d*$"
  EXE_VERSION_RE = nre.re"^Blender (.+)"

proc getArgsBlendList*(fileList: seq[string]): seq[string] =
  return filter(
    fileList,
    proc(fn: string): bool =
      fn.endsWith(BLEND_RE),
  )

proc getArgsExeList*(fileList: seq[string]): seq[string] =
  return filter(
    fileList,
    proc(fn: string): bool =
      not fn.endsWith(BLEND_RE),
  )

proc getBlenderExeVersion*(filePath: string): string =
  if not fileExists(filePath):
    return

  var
    commandStr = filePath & " --version"
    execResult: tuple[output: string, exitCode: int]
  try:
    execResult = execCmdEx(commandStr, options = {poStdErrToStdOut})
  except OSError:
    discard

  var versionMatch = execResult.output.find(EXE_VERSION_RE)
  if versionMatch.isSome:
    result = versionMatch.get.captures[0]

when isMainModule:
  let
    fileList = @[
      "a.blend",
      "b.blend1",
      "c.exe",
      "d.blend2",
      r"C:\prog\blender-4.2.0-windows-x64\blender.exe",
      r"C:\prog\blender-2.92_Parallax-Occlusion-Mapping\blender-2.92.0-git.7f0cdf968810-windows64\blender.exe",
      r"S:\sketch\nature_15.kra",
    ]
    blendList = getArgsBlendList(fileList)
    exeList = getArgsExeList(fileList)
  echo "blendList: ", blendList
  echo "exeList: ", exeList
  echo ""

  for exePath in exeList:
    echo "getBlenderExeVersion(exePath): ", getBlenderExeVersion(exePath)
    echo "exePath: ", exePath
