import std/json
import std/streams
import std/tables
import std/unittest

import configjson
import errors

test "Read nonexistent file":
  expect ConfigError:
    discard readConfigFileJSON("nonexistent.json")

test "Read empty JSON file":
  expect ConfigError:
    discard readConfigFileJSON(newStringStream(""))

test "Read wrong JSON data type":
  expect ConfigError:
    discard readConfigDataJSON(newJArray())
  expect ConfigError:
    discard readConfigDataJSON(newJBool(true))
  expect ConfigError:
    discard readConfigDataJSON(newJFloat(1.0))
  expect ConfigError:
    discard readConfigDataJSON(newJInt(1))
  expect ConfigError:
    discard readConfigDataJSON(newJNull())
  expect ConfigError:
    discard readConfigDataJSON(newJString(""))

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
    confData = readConfigDataJSON(jsonData)

  test "Read JSON data":
    check confData.paths.len == 3
