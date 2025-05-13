import std/files
import std/paths
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

proc editConfigFile*(extraTblPaths: OrderedTable[string, string]) =
  let confPath = $expandTilde(Path("~") / Path(CONFIG_JSON_NAME))
  editConfigFileJSON(confPath, extraTblPaths)

proc readConfig*(userConfPath: string = ""): ref ConfigData =
  let
    confJsonName = Path(CONFIG_JSON_NAME)
    confYamlName = Path(CONFIG_YAML_NAME)
  var
    confPathList = @[expandTilde(Path("~") / confJsonName),
                     expandTilde(Path("~") / confYamlName),
                     confJsonName.absolutePath,
                     confYamlName.absolutePath
    ]
  if userConfPath != "":
    confPathList = @[Path(userConfPath)]

  result = new ConfigData
  var fileConfData: ref ConfigData
  for p in confPathList:
    if not p.fileExists:
      continue

    stderr.writeLine("> Reading config file: ", p)
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
  let confData = readConfig()
  echo "confData: ", confData[]
