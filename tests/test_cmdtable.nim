import std/json
import std/sequtils
import std/tables
import std/unittest

import configjson
import cmdtable

let
  binPath = r"C:\prog\blender-2.93.18-windows-x64\blender.exe"
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
  cfgData = readConfigRawJSON(jsonData)

test "Get literal version spec":
  let versionSpec = getVersionSpec("4.3", cfgData.paths)
  check versionSpec == VersionSpec(literal: "4.3.3")

test "Get latest version spec":
  let versionSpec = getVersionSpec("", cfgData.paths)
  check versionSpec == VersionSpec(literal: "4.4.3")

test "Get nonexistent version spec":
  let versionSpec = getVersionSpec("999", cfgData.paths)
  check versionSpec == nil

test "Get binary path":
  let versionSpec = getVersionSpec("", cfgData.paths)
  check getCommandBinPath(versionSpec, cfgData.paths) == binPath

test "Get command line switches":
  let
    versionSpec = getVersionSpec("", cfgData.paths)
    cmdSwitches = getCommandSwitches(versionSpec, cfgData.switches)
  check cmdSwitches == "--switch4.4.3"

test "Get command line environment variables":
  let
    versionSpec = getVersionSpec("", cfgData.paths)
    cmdEnvVars = getCommandEnvVars(versionSpec, cfgData.envs)
  check "VAR4.4" in cmdEnvVars.keys.toSeq

test "Get cross-referencing version spec":
  let versionSpec = getVersionSpec("S", cfgData.paths)
  check versionSpec == VersionSpec(literal: "STORYBOARD", matching: "4.4.3")

test "Get cross-referencing version spec - empty":
  let
    jsonDataStr = r"""{
  "paths": {
    "4.4.0": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "MODELING": ""
  }
}"""
    jsonData = parseJson(jsonDataStr)
    cfgData = readConfigRawJSON(jsonData)
    versionSpec = getVersionSpec("M", cfgData.paths)
  check versionSpec == VersionSpec(literal: "MODELING", matching: "4.4.0")

test "Get cross-referencing version spec - incomplete":
  let
    jsonDataStr = r"""{
  "paths": {
    "4.4.0": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "MODELING": "4"
  }
}"""
    jsonData = parseJson(jsonDataStr)
    cfgData = readConfigRawJSON(jsonData)
    versionSpec = getVersionSpec("M", cfgData.paths)
  check versionSpec == VersionSpec(literal: "MODELING", matching: "4.4.0")

test "Get cross-referencing binary path":
  let versionSpec = getVersionSpec("S", cfgData.paths)
  check getCommandBinPath(versionSpec, cfgData.paths) == binPath

test "Get cross-referencing command line switches":
  let
    jsonDataStr = r"""{
  "paths": {
    "4.4.0": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "MODELING": "4.4.0"
  },
  "switches": {
    "4.4.0": "--switch4.4.0",
    "MOD": "--switchMOD",
  }
}"""
    jsonData = parseJson(jsonDataStr)
    cfgData = readConfigRawJSON(jsonData)
    versionSpec = getVersionSpec("M", cfgData.paths)
    cmdSwitches = getCommandSwitches(versionSpec, cfgData.switches)
  check cmdSwitches == "--switchMOD"

test "Get cross-referencing command line env variables":
  let
    jsonDataStr = r"""{
  "paths": {
    "4.4.0": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "MODELING": "4.4.0"
  },
  "envs": {
    "4": {"VAR4": ""},
    "MOD": {"VARMOD": ""},
  }
}"""
    jsonData = parseJson(jsonDataStr)
    cfgData = readConfigRawJSON(jsonData)
    versionSpec = getVersionSpec("MODEL", cfgData.paths)
    cmdEnvVars = getCommandEnvVars(versionSpec, cfgData.envs)
  check "VARMOD" in cmdEnvVars.keys.toSeq
