import std/json
import std/sequtils
import std/tables
import std/unittest

import configjson
import cmdtable

let
  jsonDataStr =
    # Use real existing binary paths, any binary, just to register
    r"""{
  "paths": {
    "2.1": null,
    "2.93": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "3.6.16": "C:\\prog\\blender-3.6.16-windows-x64\\blender.exe",
    "4.2.9": "C:\\prog\\blender-4.4.0-windows-x64\\blender.exe",
    "4.3.0": "C:\\prog\\blender-4.4.0-windows-x64\\blender.exe",
    "4.3.1": "C:\\prog\\blender-4.4.0-windows-x64\\blender.exe",
    "4.3.2": "C:\\prog\\blender-4.4.0-windows-x64\\blender.exe",
    "4.3.3": "C:\\prog\\blender-4.4.0-windows-x64\\blender.exe",
    "4.4.0": "C:\\prog\\blender-4.4.0-windows-x64\\blender.exe",
    "4.4.3": "C:\\prog\\blender-4.4.0-windows-x64\\blender.exe",
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
  cfgData = readConfigRawJSON(jsonData)

test "Get version spec":
  let initVersionSpec = ""
  check getVersionSpec(initVersionSpec, cfgData.paths) == "4.4.3"

test "Get command line switches":
  let
    initVersionSpec = ""
    versionSpec = getVersionSpec(initVersionSpec, cfgData.paths)
    cmdSwitches = getCommandSwitches(versionSpec, cfgData.switches)
  check cmdSwitches == "--switch4.4.3"

test "Get command line environment variables":
  let
    initVersionSpec = ""
    versionSpec = getVersionSpec(initVersionSpec, cfgData.paths)
    cmdEnvVars = getCommandEnvVars(versionSpec, cfgData.envs)
  check "VAR4.4" in cmdEnvVars.keys.toSeq
