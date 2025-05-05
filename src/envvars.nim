import std/os
import std/strutils
import std/tables

import constants

proc applyEnvVars*(envvars: OrderedTable[string, seq[string]]) =
  for k, v in envvars:
    var copyV = v
    let insIdx = v.find(ENV_PLACEHOLDER_ORI)
    if insIdx >= 0:
      let oriV = getEnv(k)
      if oriV != "":
        copyV[insIdx] = oriV
    putEnv(k, copyV.join($PathSep))
