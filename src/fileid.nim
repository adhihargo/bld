import std/options
import std/os
import std/osproc
import std/sequtils
import std/streams
import std/strutils
import std/sugar
import std/tables

import npeg

import cmdtable
import configdata

const
  FILEID_BPY_NAME = "fileid_bpy.py"
  FILEID_BPY_CODE = staticRead(FILEID_BPY_NAME)

let FILEID_SCR_PATH = joinPath(getAppFilename().parentDir(), FILEID_BPY_NAME)

type VersionTriplet* = array[0 .. 2, int]

let parse_blend_filename = peg "fn":
  fn <- @".blend" * *Digit * !1
proc isBlendFileName*(fn: string): bool =
  parse_blend_filename.match(fn).ok

let parse_exe_version_line = peg("ver", ver_str: string):
  ver <- "Blender" * +Space * >+1 * !1 do:
    ver_str = $1
proc readExeVersionLine*(line: string): Option[string] =
  var ver_str: string
  if parse_exe_version_line.match(line, ver_str).ok:
    return some(ver_str)

let parse_version_triplet = peg("ver", ver_triplet: VersionTriplet):
  ver <- >+Digit * ver_minor * ?ver_patch do:
    ver_triplet[0] = parseInt($1)
  ver_minor <- "." * >+Digit do:
    ver_triplet[1] = parseInt($1)
  ver_patch <- "." * >+Digit do:
    ver_triplet[2] = parseInt($1)
proc readVersionTriplet*(ver_str: string): Option[VersionTriplet] =
  var ver_triplet: VersionTriplet
  if parse_version_triplet.match(ver_str, ver_triplet).ok:
    return some(ver_triplet)

proc `<=`*(a, b: VersionTriplet): bool =
  a[0] < b[0] or (a[0] == b[0] and a[1] <= b[1])

proc getArgsBlendList*(fileList: seq[string]): seq[string] =
  return filter(
    fileList,
    proc(fn: string): bool =
      fn.isBlendFileName,
  )

proc getArgsExeList*(fileList: seq[string]): seq[string] =
  return filter(
    fileList,
    proc(fn: string): bool =
      not fn.isBlendFileName,
  )

proc writeBlenderFileIdScript() =
  if not fileExists(FILEID_SCR_PATH):
    let f_obj = newFileStream(FILEID_SCR_PATH, fmWrite)
    doAssert f_obj != nil, "Unable to create script file " & FILEID_SCR_PATH
    defer:
      f_obj.close()
    f_obj.write(FILEID_BPY_CODE)

proc execBlenderFileId(fileList: seq[string], confData: ref ConfigData): seq[string] =
  writeBlenderFileIdScript()

  let
    tblPaths = confData.paths
    versionSpec = confData.getVersionSpec()
    cmdBinPath = tblPaths.getPath(versionSpec)
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
    fileList: seq[string], confData: ref ConfigData
): OrderedTable[string, Option[VersionTriplet]] =
  let execResult = execBlenderFileId(fileList, confData)
  if execResult.len == 0:
    return

  var resultSeq: seq[(string, Option[VersionTriplet])]
  for l in execResult:
    let
      versionPairRaw = l.split("||", maxsplit = 1)
      optVersionInts = versionPairRaw[0].readVersionTriplet
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

  for line in execResult.output.split("\n"):
    let exe_version = readExeVersionLine(line)
    if exe_version.isSome:
      return exe_version.get()

proc getBlenderExeVersionTable*(fileList: seq[string]): OrderedTable[string, string] =
  let exeTable = collect(initOrderedTable):
    for exePath in fileList:
      let exeVersion = getBlenderExeVersion(exePath)
      if exeVersion != "":
        {exeVersion: exePath}
  return exeTable
