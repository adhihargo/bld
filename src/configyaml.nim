import std/json
import std/streams
import std/strformat
import std/strutils

import yaml/tojson
import yaml/parser

import configdata
import configjson
import errors

onFailedAssert(msg):
  var submsg = msg
  submsg = msg.substr(max(0, msg.rfind("` ") + 1))
  raise (ref ConfigError)(msg: submsg)

proc readConfigFileYAML*(filePath:string): seq[JsonNode] =
  let yamlFile = newFileStream(filePath)
  doAssert yamlFile != nil, "Unable to open config file " & filePath

  try:
    result = loadToJson(yamlFile)
  except YamlParserError as e:
    let mark = e.mark
    raise newException(ConfigError, &"[{mark.line}:{mark.column}] " & e.msg)

proc readConfigRawYAML*(jsConfigList: seq[JsonNode]): ref ConfigData =
  doAssert jsConfigList.len > 0, "File is empty"

  let jsConfig = jsConfigList[0]
  doAssert jsConfig.kind == JObject

  let jsVersions = readConfigRawJSON(jsConfig)
  return jsVersions

proc readConfigYAML*(cfgPath: string): ref ConfigData =
  let jsConfigList = readConfigFileYAML(cfgPath)
  result = readConfigRawYAML(jsConfigList)

when isMainModule:
  import std/tables
  import constants

  var confData: ref ConfigData
  try:
    confData = readConfigYAML(CONFIG_YAML_NAME)
  except ConfigError as e:
    stderr.writeLine("> Config error: ", e.msg)
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
