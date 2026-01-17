import std/files
import std/os
import std/paths
import std/sequtils
import std/sets
import std/tables

import constants
import configdata
import configjson
import configyaml
import errors

proc readConfigFile(cfgPath: string): ref ConfigData =
  if splitFile(Path(cfgPath)).ext == ".json":
    return readConfigJSON(cfgPath)
  else:
    return readConfigYAML(cfgPath)

proc appendConfigPaths*(extraTblPaths: PathTable) =
  let confPath = $expandTilde(Path("~") / Path(CONFIG_JSON_NAME))
  appendConfigPathsJSON(confPath, extraTblPaths)

proc readConfigFiles*(userConfPathList: seq[string] = @[]): ref ConfigData =
  let
    confJsonName = Path(CONFIG_JSON_NAME)
    confYamlName = Path(CONFIG_YAML_NAME)
    confPathSet =
      if userConfPathList.len == 0:
        [
          expandTilde(Path("~") / confJsonName),
          expandTilde(Path("~") / confYamlName),
          getAppDir().Path() / confJsonName,
          getAppDir().Path() / confYamlName,
        ].toOrderedSet
      else:
        userConfPathList.map(
          proc(i: string): Path =
            Path(i)
        ).toOrderedSet

  result = new ConfigData
  var fileConfData: ref ConfigData
  stderr.writeLine("> Reading config file(s): ")
  for p in confPathSet:
    if not p.fileExists:
      continue

    stderr.writeLine("> - ", p)
    try:
      fileConfData = readConfigFile($p)
    except ConfigError as e:
      stderr.writeLine("> Config error: ", e.msg)
    if fileConfData == nil:
      continue

    for k, v in fileConfData.paths.pairs:
      result.paths[k] = v
    for k, v in fileConfData.switches.pairs:
      result.switches[k] = v
    for k, v in fileConfData.envs.pairs:
      result.envs[k] = v

when isMainModule:
  let confData = readConfigFiles()
  echo "confData: ", confData
