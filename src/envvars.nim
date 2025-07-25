import std/os
import std/strformat
import std/strtabs
import std/strutils
import std/tables

import configdata
import constants
import errors
import scriptdir

onFailedAssert(msg):
  var submsg = msg
  submsg = msg.substr(max(0, msg.rfind("` ") + 2))
  raise (ref ConfigError)(msg: submsg)

const BLENDER_ENV_VARS = [
  "BLENDER_USER_RESOURCES", "BLENDER_USER_CONFIG", "BLENDER_USER_SCRIPTS",
  "BLENDER_USER_EXTENSIONS", "BLENDER_USER_DATAFILES", "BLENDER_SYSTEM_RESOURCES",
  "BLENDER_SYSTEM_SCRIPTS", "BLENDER_SYSTEM_EXTENSIONS", "BLENDER_SYSTEM_DATAFILES",
  "BLENDER_SYSTEM_PYTHON",
]

proc verifyEnvVar(key: string, value: string) {.inline.} =
  if key in BLENDER_ENV_VARS:
    let verifyResult = verifyScriptDir(value)
    if not verifyResult:
      stderr.writeLine("> Warning: ", key, " path may not be usable: ", value)

proc finalizeEnvVars*(envvars: EnvVarMapping): owned(StringTableRef) =
  result = newStringTable(modeCaseInsensitive)
  for k, v in envvars:
    var copyV = v
    let insIdx = v.find(ENV_PLACEHOLDER_ORI)
    if insIdx >= 0:
      let oriV = getEnv(k).strip(chars = {PathSep})
      if oriV.strip() == "":
        copyV.delete(insIdx)
      else:
        copyV[insIdx] = oriV
    doAssert copyV.find(ENV_PLACEHOLDER_ORI) < 0,
      &"[{k}] Placeholder for original value should be inserted at most once"

    let copyVStr = copyV.join($PathSep)
    verifyEnvVar(k, copyVStr)
    result[k] = copyVStr

proc applyEnvVars*(envvars: StringTableRef) =
  for k, v in envvars:
    putEnv(k, v)

when isMainModule:
  try:
    let
      testEnvVars = {"PATH": @["ABC", "*", "DEF"]}.toOrderedTable()
      finalEnvVars = testEnvVars.finalizeEnvVars()
    for k, v in finalEnvVars.pairs:
      echo k, ": ", v
  except ConfigError as e:
    stderr.writeLine("> Config error: ", e.msg)
    quit(QuitFailure)
