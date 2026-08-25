import std/strformat
import std/strutils

func getVersionString(): string =
  let (outStr, exitCode) = gorgeEx("git log -1 --format=%(describe:match=v*)-%as")
  return outStr.strip()

proc writeCodeString(fileName: string) =
  let
    versionStr = getVersionString()
    codeStr = "const versionStr* = \"$1\"\n" % [versionStr]
  echo "> Version string: ", versionStr

  withDir(thisDir()):
    writeFile(fileName, codeStr)

when isMainModule:
  writeCodeString("version.nim")
