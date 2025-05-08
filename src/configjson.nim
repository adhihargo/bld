import std/json
import std/sequtils
import std/streams
import std/strutils
import std/tables

import configdata
import errors

onFailedAssert(msg):
  var submsg = msg
  submsg = msg.substr(max(0, msg.rfind("` ") + 1))
  raise (ref ConfigError)(msg: submsg)

proc readConfigFileJSON(filePath: string): JsonNode =
  let jsonFile = newFileStream(filePath)
  doAssert jsonFile != nil, "Unable to open config file " & filePath

  var jsConfig: JsonNode = nil
  try:
    jsConfig = parseJson(jsonFile)
  except JsonParsingError as e:
    raise newException(ConfigError, "JSON read: " & e.msg)

  return jsConfig

proc readConfigRawJSON*(jsConfig: JsonNode): ref ConfigData =
  doAssert jsConfig != nil, "Invalid config JSON data"
  doAssert jsConfig.isValidConfig, "Invalid config JSON schema"

  result = new(ConfigData)
  let jsPaths = jsConfig["paths"]
  if jsPaths != nil and jsPaths.kind != JNull:
    doAssert jsPaths.kind == JObject, "Paths config JSON object must be a dictionary"
    for k, v in jsPaths.fields.pairs:
      doAssert v.kind == JString, "Path values must be string"
      result.paths[k] = v.str

  let jsSwitches = jsConfig.getOrDefault("switches")
  if jsSwitches != nil and jsSwitches.kind != JNull:
    doAssert jsSwitches.kind == JObject,
      "Switches config JSON object must be a dictionary"
    for k, v in jsSwitches.fields.pairs:
      doAssert v.kind == JString, "Switches values must be string"
      result.switches[k] = v.str

  let jsEnvs = jsConfig.getOrDefault("envs")
  if jsEnvs != nil and jsSwitches.kind != JNull:
    doAssert jsEnvs.kind == JObject, "Envs config JSON object must be a dictionary"
    for verSpec, envJSONDict in jsEnvs.fields.pairs: # VERSION -> ENVTABLE
      doAssert envJSONDict.kind == JObject,
        "Environment table values must be a dictionary"
      for envK, envV in envJSONDict.fields.pairs: # ENVVAR -> VALUELIST
        doAssert envV.kind == JString or (
          envV.kind == JArray and
          all(envV.elems, proc(v: JsonNode): bool = v.kind == JString)
        ), "Environment variable values must be a string or a list of strings"

    for verSpec, envJSONDict in jsEnvs.fields.pairs: # VERSION -> ENVTABLE
      var envTable: OrderedTable[string, seq[string]]
      for envK, envV in envJSONDict.fields.pairs: # ENVVAR -> VALUELIST
        case envV.kind
        of JArray:
          envTable[envK] = map(envV.elems, proc(j: JsonNode): string = return j.str)
        of JString:
          envTable[envK] = @[envV.str]
        else:
          raise newException(JsonParsingError, "Due to asserts, should be unreachable")
      result.envs[verSpec] = envTable

proc readConfigJSON*(cfgPath: string): ref ConfigData =
  let jsConfig = readConfigFileJSON(cfgPath)
  result = readConfigRawJSON(jsConfig)

when isMainModule:
  import constants

  var confData: ref ConfigData
  try:
    confData = readConfigJSON(CONFIG_JSON_NAME)
  except ConfigError as e:
    echo "> Config error: ", e.msg
    quit(QuitFailure)

  if confData != nil:
    echo "> PATHS:"
    for k, v in confData.paths.pairs:
      echo k, ": ", v
    echo "> SWITCHES:"
    for k, v in confData.switches.pairs:
      echo k, ": ", v
    echo "> ENVS:"
    for k, v in confData.envs.pairs:
      echo k, ": ", v
