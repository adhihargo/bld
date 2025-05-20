import cmdtable
import configdata
import std/nre
import std/options
import std/os
import std/osproc
import std/sequtils
import std/streams
import std/strutils
import std/sugar

let
  BLEND_RE = re"\.blend\d*$"
  EXE_VERSION_RE = re"^Blender (.+)"
  BLEND_VERSION_RE = re"v(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)"

const
  FILEID_BPY_NAME = "fileid_bpy.py"
  FILEID_BPY_CODE = staticRead(FILEID_BPY_NAME)

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
  let fileid_scr_path = joinPath(getAppFilename().parentDir(), FILEID_BPY_NAME)
  if not fileExists(fileid_scr_path):
    let f_obj = newFileStream(fileid_scr_path, fmWrite)
    doAssert f_obj != nil, "Unable to create script file " & fileid_scr_path
    defer:
      f_obj.close()
    f_obj.write(FILEID_BPY_CODE)

proc execBlenderFileId(fileList: seq[string], confData: ref ConfigData): seq[string] =
  writeBlenderFileIdScript()

  let
    versionSpec = getVersionSpec("", confData.paths)
    cmdBinPath = getCommandBinPath(versionSpec, confData.paths)
  if not fileExists(cmdBinPath):
    stderr.writeLine("> File ID binary path not found: ", cmdBinPath)
    return

  let
    fileListStr = fileList.quoteShellCommand
    commandStr = @[
      cmdBinPath, "-b", "--factory-startup", "-P", FILEID_BPY_NAME, fileListStr
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

proc getBlenderFileVersionList*(
    fileList: seq[string], confData: ref ConfigData
): seq[(array[0..2, string], string)] =
  doAssert confData != nil, "Must pass valid config data"

  let execResult = execBlenderFileId(fileList, confData)
  if execResult.len == 0:
    return

  for l in execResult:
    let
      versionPairRaw = l.split("||", maxsplit = 1)
      optVerMatch = versionPairRaw[0].find(BLEND_VERSION_RE)
    if optVerMatch.isNone():
      continue

    let
      mc = optVerMatch.get().captures
      versionArray = [mc[0], mc[1], mc[2]]
    result.add((versionArray, versionPairRaw[1]))

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

  import config
  let confData = readConfig()

  let versionList = getBlenderFileVersionList(blendList, confData)
  for vp in versionList:
    echo "vp: ", vp
  
  for exePath in exeList:
    echo "getBlenderExeVersion(exePath): ", getBlenderExeVersion(exePath)
    echo "exePath: ", exePath
