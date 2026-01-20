import std/files
import std/os
import std/paths
import std/sequtils
import std/sets
import std/tables
import std/unicode

import constants
import configdata
import configjson
import configyaml
import errors

proc readConfigFile*(confPath: string): ref ConfigData =
  stderr.writeLine("> Reading existing config file: " & confPath)
  if splitFile(Path(confPath)).ext == ".json":
    return readConfigJSON(confPath)
  else:
    return readConfigYAML(confPath)

proc appendConfigPaths*(extraTblPaths: PathTable) =
  let confPath = $expandTilde(Path("~") / Path(CONFIG_JSON_NAME))
  updateConfigPathsJSON(confPath, extraTblPaths)

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

proc getBinaryPathRoots*(confData: ref ConfigData): seq[string] =
  let tblPaths = confData.paths
  var rootPathSet: OrderedSet[string]
  for binPath in tblPaths.values:
    # paths assumed to be absolute, referring to a file that may no
    # longer exist.
    let rootDir = binPath.parentDir.parentDir
    if rootDir.dirExists:
      rootPathSet.incl(rootDir)
  return rootPathSet.toSeq

proc scanSubDirs(rootPath: string): seq[string] =
  for pathKind, dirPath in walkDir(rootPath):
    if pathKind != pcDir:
      continue
    for pathKind, fileName in walkDir(dirPath, relative = true):
      if pathKind != pcFile or fileName.toLower != "blender.exe":
        continue
      let filePath = dirPath / fileName
      result.add(filePath)
      break

proc getBinaryPaths*(rootPathList: seq[string]): seq[string] =
  for pathStr in rootPathList:
    let binPathList = scanSubDirs(pathStr)
    result.add(binPathList)

when isMainModule:
  let confData = readConfigFiles()
  echo "confData: ", confData
