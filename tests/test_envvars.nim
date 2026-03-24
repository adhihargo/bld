include envvars

import std/envvars
import std/json
import std/unittest

import configjson

let
  jsonDataStr =
    # Use real existing binary paths, any binary, just to register
    r"""{
  "paths": {
    "2.1": null,
    "2.93": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "3.6.16": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "4.2.9": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "4.3.0": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "4.3.1": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "4.3.2": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "4.3.3": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "4.4.0": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "4.4.3": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "4.4.4": "Nonexistent path, must be ignored",
    "STORYBOARD": "4.4.3",
  },
  "switches": {
    "4": "--switch4",
    "4.3": "--switch4.3",
    "4.3.1": "--switch4.3.1",
    "4.3.2": "--switch4.3.2",
    "4.4": "--switch4.4",
    "4.4.0": "--switch4.4.0",
    "4.4.3": "--switch4.4.3",
  },
  "envs": {
    "4": {"VAR4": ""},
    "4.4": {"VAR4.4": ""},
    "4.3": {"VAR4.3": ""},
  }
}"""
  jsonData = parseJson(jsonDataStr)
  confData = jsonData.toConfigData

test "Placeholder replacement":
  putEnv("PATH_DUMMY", "GHI")
  let
    testEnvVars = {"PATH_DUMMY": @["ABC", "*", "DEF"]}.toOrderedTable()
    finalEnvVars = testEnvVars.finalizeEnvVars()
  delEnv("PATH_DUMMY")
  check finalEnvVars["PATH_DUMMY"] == "ABC;GHI;DEF"

test "Version spec insertion":
  let
    versionSpec = confData.getVersionSpec("S")
    cmdEnvVars = confData.envs.get(versionSpec).finalizeEnvVars

  applyEnvVars(versionSpec, cmdEnvVars)
  check:
    getEnv("BLD_VERSIONSPEC") == "STORYBOARD"
    getEnv("BLD_VERSIONSPEC_MATCHING") == "4.4.3"
