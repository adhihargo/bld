import std/os
import std/sequtils
import std/strutils

proc verifyScriptDir*(varName, dirPath: string): bool =
  if all(
    @["_CONFIG", "_EXTENSIONS", "_SCRIPTS", "_RESOURCES", "_DATAFILES", "_PYTHON"],
    proc(nameSuffix: string): bool =
      not varName.endsWith(nameSuffix),
  ):
    return true

  try:
    if not dirPath.dirExists:
      dirPath.createDir()
    if varName.endsWith("_SCRIPTS"):
      let subdirs = ["addons", "startup"]
      for d in subdirs:
        let subdirPath = dirPath / d
        if not subdirPath.dirExists:
          subdirPath.createDir()
    return true
  except OSError as e:
    stderr.writeLine("> OS error: ", dirPath.quoteShell, ": ", e.msg)
    return false
