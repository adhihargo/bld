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

proc readConfigFileYAML(confPath: string): seq[JsonNode] =
  let yamlFile = newFileStream(confPath)
  doAssert yamlFile != nil, "Unable to open config file " & confPath

  try:
    result = loadToJson(yamlFile)
  except YamlParserError as e:
    let mark = e.mark
    raise newException(ConfigError, &"[{mark.line}:{mark.column}] " & e.msg)

proc readConfigRawYAML(jsConfigList: seq[JsonNode], confPath: string): ref ConfigData =
  doAssert jsConfigList.len > 0, "File is empty"

  let jsConfig = jsConfigList[0]
  doAssert jsConfig.kind == JObject

  let jsVersions = jsConfig.toConfigData(confPath)
  return jsVersions

proc readConfigYAML*(confPath: string): ref ConfigData =
  ## Read YAML file `confPath`, returning config data.

  let jsConfigList = readConfigFileYAML(confPath)
  result = readConfigRawYAML(jsConfigList, confPath)
