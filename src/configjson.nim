import std/json
import std/jsonutils
import std/sequtils
import std/streams
import std/strutils
import std/tables

import configdata
import errors

onFailedAssert(msg):
  var submsg = msg
  submsg = msg.substr(max(0, msg.rfind("` ") + 2))
  raise (ref ConfigError)(msg: submsg)

proc readConfigFileJSON(filePath: string): JsonNode =
  let jsonFile = newFileStream(filePath)
  doAssert jsonFile != nil, "Unable to open config file " & filePath

  var jsConfig = newJNull()
  try:
    jsConfig = parseJson(jsonFile)
  except JsonParsingError as e:
    raise newException(ConfigError, "JSON read: " & e.msg)

  return jsConfig

proc readConfigRawJSON*(jsConfig: JsonNode): ref ConfigData =
  doAssert jsConfig.kind != JNull, "Invalid config JSON data"
  doAssert jsConfig.isValidConfig, "Invalid config JSON schema"

  result = new(ConfigData)
  let jsPaths = jsConfig.fields.getOrDefault("paths", newJNull())
  if jsPaths.kind != JNull:
    doAssert jsPaths.kind == JObject, "Paths config JSON object must be a dictionary"
    try:
      result.paths = jsPaths.jsonTo(PathTable)
    except JsonKindError as e:
      raise newException(ConfigError, e.msg)

  let jsSwitches = jsConfig.fields.getOrDefault("switches", newJNull())
  if jsSwitches.kind != JNull:
    doAssert jsSwitches.kind == JObject,
      "Switches config JSON object must be a dictionary"
    try:
      result.switches = jsSwitches.jsonTo(PathTable)
    except JsonKindError as e:
      raise newException(ConfigError, e.msg)

  let jsEnvs = jsConfig.fields.getOrDefault("envs", newJNull())
  if jsEnvs.kind != JNull:
    doAssert jsEnvs.kind == JObject, "Envs config JSON object must be a dictionary"
    for verSpec, envJSONDict in jsEnvs.fields.pairs: # VERSION -> ENVTABLE
      doAssert envJSONDict.kind == JObject,
        "Environment table values must be a dictionary"
      for envK, envV in envJSONDict.fields.pairs: # ENVVAR -> VALUELIST
        doAssert envV.kind == JString or (
          envV.kind == JArray and
          all(
            envV.elems,
            proc(v: JsonNode): bool =
              v.kind == JString,
          )
        ), "Environment variable values must be a string or a list of strings"

    for verSpec, envJSONDict in jsEnvs.fields.pairs: # VERSION -> ENVTABLE
      var envTable: OrderedTable[string, seq[string]]
      for envK, envV in envJSONDict.fields.pairs: # ENVVAR -> VALUELIST
        case envV.kind
        of JArray:
          envTable[envK] = map(
            envV.elems,
            proc(j: JsonNode): string =
              return j.str,
          )
        of JString:
          envTable[envK] = @[envV.str]
        else:
          raise newException(JsonParsingError, "Due to asserts, should be unreachable")
      result.envs[verSpec] = envTable

proc readConfigJSON*(cfgPath: string): ref ConfigData =
  let jsConfig = readConfigFileJSON(cfgPath)
  result = readConfigRawJSON(jsConfig)

proc writeConfigFileJSON(confPath: string, jsConfig: JsonNode) =
  let jsonFile = newFileStream(confPath, fmWrite)
  defer:
    jsonFile.close
  jsonFile.write(jsConfig.pretty)

proc editConfigFileJSON*(
    confPath: string, extraTblPaths: PathTable
) =
  let jsConfig = readConfigFileJSON(confPath)
  stderr.writeLine("> Reading existing config file: " & confPath)
  try:
    doAssert jsConfig.kind == JObject
    let jsPaths = jsConfig.fields.getOrDefault("paths", newJNull())
    var tblPaths = jsPaths.jsonTo(PathTable)
    for k, v in extraTblPaths:
      tblPaths[k] = v
    tblPaths.sort(cmp)
    jsConfig["paths"] = tblPaths.toJson
  except JsonKindError as e:
    raise newException(ConfigError, e.msg)

  writeConfigFileJSON(confPath, jsConfig)

when isMainModule:
  import std/paths
  import constants

  try:
    let
      extraTblPaths = {"A": "C01", "B": "B01"}.toOrderedTable
      confPath = $expandTilde(Path("~") / Path(CONFIG_JSON_NAME))
    editConfigFileJSON(confPath, extraTblPaths)
  except ConfigError as e:
    stderr.writeLine("> Config error: " & e.msg)
    quit(QuitFailure)

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
