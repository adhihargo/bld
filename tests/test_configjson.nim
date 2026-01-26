include configjson

import std/paths
import std/unittest

import constants

block:
  let basePath = r"C:\abc\def\ghi\jkl"
  test "Substitute relative path marker - simple":
    let absPath = r"\\MNO".toAbsPath(basePath)
    check absPath == r"C:\abc\def\ghi\jkl\MNO"
  test "Substitute relative path marker - current level":
    let absPath = r"\\.\MNO".toAbsPath(basePath)
    check absPath == r"C:\abc\def\ghi\jkl\MNO"
  test "Substitute relative path marker - one level up":
    let absPath = r"\\..\MNO".toAbsPath(basePath)
    check absPath == r"C:\abc\def\ghi\MNO"
  test "Substitute relative path marker - two levels up":
    let absPath = r"\\...\MNO".toAbsPath(basePath)
    check absPath == r"C:\abc\def\MNO"

test "Read nonexistent file":
  expect ConfigError:
    discard readConfigFileJSON("nonexistent.json")

test "Read empty JSON file":
  expect ConfigError:
    discard readConfigFileJSON(newStringStream(""))

test "Read wrong JSON data type":
  expect ConfigError:
    discard newJArray().toConfigData
  expect ConfigError:
    discard newJBool(true).toConfigData
  expect ConfigError:
    discard newJFloat(1.0).toConfigData
  expect ConfigError:
    discard newJInt(1).toConfigData
  expect ConfigError:
    discard newJNull().toConfigData
  expect ConfigError:
    discard newJString("").toConfigData

test "Read invalid JSON data string":
  let
    jsonDataStr = r"""{"""
    jsonStream = newStringStream(jsonDataStr)
  expect ConfigError:
    discard readConfigFileJSON(jsonStream)

block:
  let
    jsonDataStr =
      r"""{
  "paths": {
    "1": null,
    "4.3.2": "C:\\prog\\blender-4.3.2-windows-x64\\blender.exe",
    "4.4.0": "C:\\prog\\blender-4.4.0-windows-x64\\blender.exe"
  },
  "switches": {
    "4.3": "--version",
    "4.4": "--background"
  }
}"""
    jsonData = parseJson(jsonDataStr)
    confData = jsonData.toConfigData

  test "Read JSON data":
    check confData.paths.len == 3

proc main() =
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

when isMainModule:
  main()
