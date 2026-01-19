import std/nre
import std/options
import std/os
import std/osproc
import std/sequtils
import std/streams
import std/strutils
import std/sugar
import std/tables

import cmdtable
import configdata

const
  FILEID_BPY_NAME = "fileid_bpy.py"
  FILEID_BPY_CODE = staticRead(FILEID_BPY_NAME)

let
  BLEND_RE = re"\.blend\d*$"
  EXE_VERSION_RE = re"^Blender (.+)"
  BLEND_VERSION_RE = re"(?<major>\d+)\.(?<minor>\d+)\.?(?<patch>\d+)?"
  FILEID_SCR_PATH = joinPath(getAppFilename().parentDir(), FILEID_BPY_NAME)

type VersionTriplet* = array[0 .. 2, int]

proc `<=`*(a, b: VersionTriplet): bool =
  a[0] < b[0] or (a[0] == b[0] and a[1] <= b[1])

proc toVersionTriplet*(versionStr: string): Option[VersionTriplet] =
  let optMatch = versionStr.find(BLEND_VERSION_RE)
  if optMatch.isSome:
    var
      match = optMatch.get()
      capts = match.captures.toSeq
      verInts = [0, 0, 0]
    for i, v in capts:
      verInts[i] =
        if v.isSome():
          v.get().parseInt()
        else:
          0
    return some(verInts)

proc getArgsBlendList*(fileList: seq[string]): seq[string] =
  return filter(
    fileList,
    proc(fn: string): bool =
      fn.contains(BLEND_RE),
  )

proc getArgsExeList*(fileList: seq[string]): seq[string] =
  return filter(
    fileList,
    proc(fn: string): bool =
      not fn.contains(BLEND_RE),
  )

proc writeBlenderFileIdScript() =
  if not fileExists(FILEID_SCR_PATH):
    let f_obj = newFileStream(FILEID_SCR_PATH, fmWrite)
    doAssert f_obj != nil, "Unable to create script file " & FILEID_SCR_PATH
    defer:
      f_obj.close()
    f_obj.write(FILEID_BPY_CODE)

proc execBlenderFileId(fileList: seq[string], tblPaths: PathTable): seq[string] =
  writeBlenderFileIdScript()

  let
    versionSpec = getVersionSpec("", tblPaths)
    cmdBinPath = getCommandBinPath(versionSpec, tblPaths)
  if not fileExists(cmdBinPath):
    stderr.writeLine("> File ID binary path not found: ", cmdBinPath)
    return

  let
    fileListStr = fileList.filter(fileExists).quoteShellCommand
    commandStr = @[
      cmdBinPath, "-b", "--factory-startup", "-P", FILEID_SCR_PATH.quoteShell,
      fileListStr,
    ].join(" ")
  var execResult: tuple[output: string, exitCode: int]
  try:
    execResult = execCmdEx(commandStr)
  except OSError as e:
    stderr.writeLine("> File ID command: ", commandStr)
    stderr.writeLine("> File ID OS error: ", e.msg)

  result = collect:
    for l in execResult.output.split("\n"):
      if l.startsWith("BLENDERv"):
        l

proc getBlenderFileVersionTable*(
    fileList: seq[string], tblPaths: PathTable
): OrderedTable[string, Option[VersionTriplet]] =
  let execResult = execBlenderFileId(fileList, tblPaths)
  if execResult.len == 0:
    return

  var resultSeq: seq[(string, Option[VersionTriplet])]
  for l in execResult:
    let
      versionPairRaw = l.split("||", maxsplit = 1)
      optVersionInts = versionPairRaw[0].toVersionTriplet()
    if optVersionInts.isNone():
      continue

    let versionInts = optVersionInts.get()
    resultSeq.add((versionPairRaw[1], some(versionInts)))
  return resultSeq.toOrderedTable

proc getBlenderExeVersion(filePath: string): string =
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

proc getBlenderExeVersionTable*(fileList: seq[string]): OrderedTable[string, string] =
  let exeTable = collect(initOrderedTable):
    for exePath in fileList:
      let exeVersion = getBlenderExeVersion(exePath)
      if exeVersion != "":
        {exeVersion: exePath}
  return exeTable  

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

  import config
  let confData = readConfigFiles()
  if confData == nil:
    quit(QuitFailure)

  let versionTable = getBlenderFileVersionTable(blendList, confData.paths)
  for fp, fv in versionTable.pairs:
    echo fp, ": ", fv

  for exePath in exeList:
    echo "getBlenderExeVersion(exePath): ", getBlenderExeVersion(exePath)
    echo "exePath: ", exePath
