import std/unittest
import std/json
import std/streams
import std/tables

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
    discard readConfigRawJSON(newJArray())
  expect ConfigError:
    discard readConfigRawJSON(newJBool(true))
  expect ConfigError:
    discard readConfigRawJSON(newJFloat(1.0))
  expect ConfigError:
    discard readConfigRawJSON(newJInt(1))
  expect ConfigError:
    discard readConfigRawJSON(newJNull())
  expect ConfigError:
    discard readConfigRawJSON(newJString(""))

test "Read invalid JSON data string":
  let
    jsonDataStr = r"""{"""
    jsonStream = newStringStream(jsonDataStr)
  expect ConfigError:
    discard readConfigFileJSON(jsonStream)

test "Read JSON data":
  let
    jsonDataStr =
      r"""{
  "paths": {
    "1": null,
    "4.3.2": "C:\prog\blender-4.3.2-windows-x64\blender.exe",
    "4.4.0": "C:\prog\blender-4.4.0-windows-x64\blender.exe"
  },
  "switches": {
    "4.3": "--version",
    "4.4": "--background"
  }
}"""
    jsonData = parseJson(jsonDataStr)
    cfgData = readConfigRawJSON(jsonData)
  check cfgData.paths.len == 3
