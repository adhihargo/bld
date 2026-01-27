import std/json
import std/jsonutils
import std/os
import std/sequtils
import std/streams
import std/strutils
import std/tables

import npeg

import configdata
import errors

onFailedAssert(msg):
  var submsg = msg
  submsg = msg.substr(max(0, msg.rfind("` ") + 2))
  raise (ref ConfigError)(msg: submsg)

let parse_rel_path = peg("rel_path", parentLevel: int):
  rel_path <- '\\'[2] * ?parent_ref * &!'\\'
  parent_ref <- ?('.' * >*'.') * '\\':
    parentLevel = len($1)
proc toAbsPath(pathStr, basePath: string): string =
  ## Replace relative path prefix in `pathStr` with `basePath`. The
  ## prefix is a double-backslash, followed by an optional sequence of
  ## periods counting levels of directories to go up ended by a
  ## backslash.

  if basePath == "":
    return pathStr

  var
    parentPath = basePath
    parentLevel = 0
  let matchObj = parse_rel_path.match(pathStr, parentLevel)
  return
    if matchObj.ok:
      for i in countdown(parentLevel, 1):
        parentPath = parentPath.parentDir
      parentPath / pathStr.substr(matchObj.matchMax)
    else:
      pathStr

proc readConfigFileJSON(fileStream: Stream, confPath: string = ""): JsonNode =
  doAssert fileStream != nil, "Unable to open config file " & confPath

  var jsConfig = newJObject()
  try:
    jsConfig = parseJson(fileStream)
  except JsonParsingError as e:
    raise newException(ConfigError, "JSON read: " & e.msg)

  return jsConfig

proc readConfigFileJSON(confPath: string, create: bool = false): JsonNode =
  return
    if not confPath.fileExists and create:
      newJObject()
    else:
      let jsonFile = newFileStream(confPath)
      readConfigFileJSON(jsonFile, confPath)

template verify_store_stringtable(jsObj, resultVar, errMsg) =
  if jsObj.kind != JNull:
    doAssert jsObj.kind == JObject, errMsg
    try:
      resultVar = jsObj.jsonTo(PathTable)
    except JsonKindError as e:
      raise newException(ConfigError, e.msg)

proc toConfigData*(jsConfig: JsonNode, confPath: string = ""): ref ConfigData =
  ## Verify and convert JSON node `jsConfig` into config data.

  doAssert jsConfig.kind == JObject, "Invalid config JSON data"
  doAssert jsConfig.isValidConfig, "Invalid config JSON schema"

  result = new(ConfigData)
  let confDirPath = confPath.parentDir

  let jsPaths = jsConfig.fields.getOrDefault("paths", newJNull())
  verify_store_stringtable(
    jsPaths, result.paths, "Paths config JSON object must be a dictionary"
  )

  let jsSwitches = jsConfig.fields.getOrDefault("switches", newJNull())
  verify_store_stringtable(
    jsSwitches, result.switches, "Switches config JSON object must be a dictionary"
  )

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
              return j.str.toAbsPath(confDirPath),
          )
        of JString:
          envTable[envK] = @[envV.str.toAbsPath(confDirPath)]
        else:
          raise newException(JsonParsingError, "Due to asserts, should be unreachable")
      result.envs[verSpec] = envTable

  for k in result.paths.keys:
    result.paths[k] = result.paths[k].toAbsPath(confDirPath)

proc readConfigJSON*(confPath: string): ref ConfigData =
  ## Read JSON file `confPath`, returning config data.

  let jsConfig = readConfigFileJSON(confPath)
  result = jsConfig.toConfigData(confPath)

proc writeConfigFileJSON(confPath: string, jsConfig: JsonNode) =
  let jsonFile = newFileStream(confPath, fmWrite)
  defer:
    jsonFile.close
  jsonFile.write(jsConfig.pretty)

proc updateConfigPathsJSON*(confPath: string, extraTblPaths: PathTable) =
  ## Add path table `extraTblPaths` to config file `confPath`, prune
  ## missing files from existing table, and save the file.

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
