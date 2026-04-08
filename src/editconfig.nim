import configdata
import constants
import config
import configjson
import errors
import fileid

import std/os
import std/paths
import std/tables
import std/sequtils

proc printExeVersions(exeTable: PathTable) =
  stderr.writeLine("> Registering Blender versions: ")
  for v in exeTable.keys:
    stderr.writeLine("> -v:", v)

proc appendConfigPaths*(extraTblPaths: PathTable, confPath: string = "") =
  let
    confPath =
      if confPath == "":
        $expandTilde(Path("~") / Path(CONFIG_JSON_NAME))
      else:
        confPath

  if extraTblPaths.len > 0:
    printExeVersions(extraTblPaths)
  updateConfigPathsJSON(confPath, extraTblPaths)

proc updateConfigPaths*(confPath: string = "") =
  let confPath =
    if confPath == "":
      $expandTilde(Path("~") / Path(CONFIG_JSON_NAME))
    else:
      confPath
  if not fileExists(confPath):
    raise ConfigError.newException("Configuration file ")

  let
    confData = readConfigFile(confPath)
    pathRoots = getBinaryPathRoots(confData)
    existingBinaryPaths = confData.paths.values.toSeq
    binaryPaths = getBinaryPaths(pathRoots)
    newBinaryPaths = binaryPaths.filter(
      proc(fp: string): bool =
        fp notin existingBinaryPaths
    )
    newBinaryTable = getBlenderExeVersionTable(newBinaryPaths)

  appendConfigPaths(newBinaryTable, confPath)
