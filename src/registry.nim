import std/registry
import std/options
import std/os
import std/strutils

proc getRegistryValue(path, key: string, handle: HKEY): Option[string] =
  when not defined(windows):
    return none(string)

  try:
    let value = getUnicodeValue(path, key, handle)
    result = some(value)
  except OSError:
    result = none(string)

proc setRegistryValue(path, key, val: string, handle: HKEY): bool =
  when not defined(windows):
    return false

  try:
    setUnicodeValue(path, key, val, handle)
    result = true
  except OSError:
    result = false

proc registerExtHandler*(binPath: string, passedArgs: string = ""): bool =
  let
    regExtPath = r"SOFTWARE\Classes\.blend"
    defaultExtHandlerName = "blendfile"
    optExtHandlerName = getRegistryValue(regExtPath, "", HKEY_CURRENT_USER)
  if optExtHandlerName.isNone() and
      not setRegistryValue(regExtPath, "", defaultExtHandlerName, HKEY_CURRENT_USER):
    stderr.writeLine("> Unable to edit file extension registry path")
    return false

  let
    regCmdvalue = [binPath.quoteShell, passedArgs, "\"%1\""].join(" ")
    regExtHandlerPath =
      [r"SOFTWARE\Classes", optExtHandlerName.get(), r"shell\open\command"].join("\\")
  return setRegistryValue(regExtHandlerPath, "", regCmdvalue, HKEY_CURRENT_USER)

when isMainModule:
  let
    binPath = r"S:\coding\nim\launch\bld.exe"
    resultStr = if registerExtHandler(binPath): "SUCCESS" else: "FAILURE"
  echo "resultStr: ", resultStr
