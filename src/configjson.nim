import std/json
import std/jsonutils
import std/os
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

proc readConfigFileJSON*(fileStream: Stream, confPath: string = ""): JsonNode =
  doAssert fileStream != nil, "Unable to open config file " & confPath

  var jsConfig = newJObject()
  try:
    jsConfig = parseJson(fileStream)
  except JsonParsingError as e:
    raise newException(ConfigError, "JSON read: " & e.msg)

  return jsConfig

proc readConfigFileJSON*(confPath: string, create: bool = false): JsonNode =
  return
    if not confPath.fileExists and create:
      newJObject()
    else:
      let jsonFile = newFileStream(confPath)
      readConfigFileJSON(jsonFile, confPath)

proc readConfigDataJSON*(jsConfig: JsonNode): ref ConfigData =
  doAssert jsConfig.kind == JObject, "Invalid config JSON data"
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
      var envTable: EnvVarMapping
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

proc readConfigJSON*(confPath: string): ref ConfigData =
  let jsConfig = readConfigFileJSON(confPath)
  result = readConfigDataJSON(jsConfig)

proc writeConfigFileJSON(confPath: string, jsConfig: JsonNode) =
  let jsonFile = newFileStream(confPath, fmWrite)
  defer:
    jsonFile.close
  jsonFile.write(jsConfig.pretty)

proc updateConfigPathsJSON*(confPath: string, extraTblPaths: PathTable) =
  let jsConfig = readConfigFileJSON(confPath, create = true)
  try:
    let jsPaths = jsConfig.fields.getOrDefault("paths", newJObject())
    var tblPaths = jsPaths.jsonTo(PathTable)
    for i in tblPaths.pairs.toSeq:
      if not fileExists(i[1]):
        tblPaths.del(i[0])

    let existingKeys = tblPaths.keys.toSeq
    for k, v in extraTblPaths:
      var
        k_new = k
        k_idx = 1
      while k_new in existingKeys:
        echo "> ", k_new, " exists"
        # Add numeric suffix if an existing path uses similar key
        k_new = k & "_" & intToStr(k_idx)
        k_idx += 1
      tblPaths[k_new] = v
    tblPaths.sort(cmp)
    jsConfig["paths"] = tblPaths.toJson
  except JsonKindError as e:
    raise newException(ConfigError, e.msg)

  writeConfigFileJSON(confPath, jsConfig)

when isMainModule:
  import std/paths
  import constants

  let
    extraTblPaths = {"A": "C01", "B": "B01"}.toOrderedTable
    confPath = $expandTilde(Path("~") / Path(CONFIG_JSON_NAME))
  try:
    updateConfigPathsJSON(confPath, extraTblPaths)
  except ConfigError as e:
    stderr.writeLine("> Config error: " & e.msg)
    quit(QuitFailure)

  var confData: ref ConfigData
  try:
    confData = readConfigJSON(confPath)
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
