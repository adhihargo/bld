import std/json
import std/options
import std/strutils
import std/tables
import jsonschema

jsonSchema:
  ConfigSchema:
    paths ?: any
    switches ?: any
    envs ?: any

type
  PathTable* = OrderedTable[string, string]
  EnvVarMapping* = OrderedTable[string, seq[string]]
  ConfigData* = object
    paths*: PathTable
    switches*: PathTable
    envs*: OrderedTable[string, EnvVarMapping]

proc isValidConfig*(jsonNode: JsonNode): bool =
  return isValid(jsonNode, ConfigSchema)

proc sort*(confData: ref ConfigData) =
  confData.paths.sort(cmp)
  confData.switches.sort(cmp)
  confData.envs.sort(
    proc(x, y: (string, EnvVarMapping)): int =
      cmp(x[0], y[0])
  )
  for k in confData.envs.keys:
    var v = confData.envs[k]
    v.sort(
      proc(x, y: (string, seq[string])): int =
        cmp(x[0], y[0])
    )
    confData.envs[k] = v

proc `$`*(confData: ref ConfigData): string =
  let
    ind1 = " ".repeat(2)
    ind2 = ind1.repeat(2)
    ind3 = ind1.repeat(3)
    ind4 = ind1.repeat(4)
  result = "ConfigData(\n"
  if confData.paths.len > 0:
    result &= ind1 & "paths:\n"
    for k, v in confData.paths.pairs:
      result &= "$#$#: $#\n" % [ind2, k, v]
  if confData.switches.len > 0:
    result &= ind1 & "switches:\n"
    for k, v in confData.switches.pairs:
      result &= "$#$#: $#\n" % [ind2, k, v]
  if confData.envs.len > 0:
    result &= ind1 & "envs:\n"
    for k, v in confData.envs.pairs:
      result &= "$#$#:\n" % [ind2, k]
      for k1, v1 in v.pairs:
        if v1.len == 1:
          result &= "$#$#: $#\n" % [ind3, k1, v1[0]]
        else:
          result &= "$#$#:\n" % [ind3, k1]
          for v2 in v1:
            result &= "$#- $#\n" % [ind4, v2]
