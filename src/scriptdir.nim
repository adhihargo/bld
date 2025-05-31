import std/os

proc verifyScriptDir*(dirPath: string): bool =
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
