import std/os
import std/strutils

proc verifyScriptDir*(dirPath: string): bool =
  if not dirPath.endsWith("_SCRIPTS"):
    return true

  try:
    let subdirs = ["addons", "startup"]
    for d in subdirs:
      let subdirPath = dirPath / d
      if not subdirPath.dirExists:
        subdirPath.createDir()
    return true
  except OSError as e:
    stderr.writeLine("> OS error: ", dirPath.quoteShell, ": ", e.msg)
    return false

when isMainModule:
  discard verifyScriptDir(r"Z:\home\blender\v2\scripts")
