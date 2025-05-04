import std/files
import std/os
import std/paths

import constants
import configdata
import configjson
import configyaml
import errors

proc getConfigPath*(cfgPath: string): string =
  if cfgPath != "":
    if not cfgPath.fileExists:
      raise newException(ConfigError, "File does not exist: " & cfgPath)
    return cfgPath

  let
    cfgAppPath = Path(CONFIG_YAML_NAME)
    cfgHomePath = expandTilde(Path("~") / cfgAppPath)
  if cfgHomePath.fileExists:
    return $cfgHomePath
  else:
    return $cfgAppPath

proc readConfig*(cfgPath: string): ref ConfigData =
  if splitFile(Path(cfgPath)).ext == ".json":
    return readConfigJSON(cfgPath)
  else:
    return readConfigYAML(cfgPath)
