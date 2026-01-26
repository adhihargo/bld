include cmdtable

import std/json
import std/unittest

import config
import configjson


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
  confData = jsonData.toConfigData

test "Get literal version spec":
  let versionSpec = confData.getVersionSpec("4.3")
  check versionSpec == VersionSpec(literal: "4.3.3")

test "Get latest version spec":
  let versionSpec = confData.getVersionSpec()
  check versionSpec == VersionSpec(literal: "4.4.3")

test "Get nonexistent version spec":
  let versionSpec = confData.getVersionSpec("999")
  check versionSpec == nil

test "Get binary path":
  let versionSpec = confData.getVersionSpec()
  check confData.paths.getPath(versionSpec) == binPath

test "Get command line switches":
  let
    versionSpec = confData.getVersionSpec()
    cmdSwitches = confData.switches.get(versionSpec)
  check cmdSwitches == "--switch4.4.3"

test "Get command line environment variables":
  let
    versionSpec = confData.getVersionSpec()
    cmdEnvVars = confData.envs.get(versionSpec)
  check "VAR4.4" in cmdEnvVars.keys.toSeq

test "Get cross-referencing version spec":
  let versionSpec = confData.getVersionSpec("S")
  check versionSpec == VersionSpec(literal: "STORYBOARD", matching: "4.4.3")

test "Get cross-referencing version spec - empty":
  let
    jsonDataStr =
      r"""{
  "paths": {
    "4.4.0": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "MODELING": ""
  }
}"""
    jsonData = parseJson(jsonDataStr)
    confData = jsonData.toConfigData
    versionSpec = confData.getVersionSpec("M")
  check versionSpec == VersionSpec(literal: "MODELING", matching: "4.4.0")

test "Get cross-referencing version spec - incomplete":
  let
    jsonDataStr =
      r"""{
  "paths": {
    "4.4.0": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "MODELING": "4"
  }
}"""
    jsonData = parseJson(jsonDataStr)
    confData = jsonData.toConfigData
    versionSpec = confData.getVersionSpec("M")
  check versionSpec == VersionSpec(literal: "MODELING", matching: "4.4.0")

test "Get cross-referencing binary path":
  let versionSpec = confData.getVersionSpec("S")
  check confData.paths.getPath(versionSpec) == binPath

test "Get cross-referencing command line switches":
  let
    jsonDataStr =
      r"""{
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
    confData = jsonData.toConfigData
    versionSpec = confData.getVersionSpec("M")
    cmdSwitches = confData.switches.get(versionSpec)
  check cmdSwitches == "--switchMOD"

test "Get cross-referencing command line env variables":
  let
    jsonDataStr =
      r"""{
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
    confData = jsonData.toConfigData
    versionSpec = confData.getVersionSpec("MODEL")
    cmdEnvVars = confData.envs.get(versionSpec)
  check "VARMOD" in cmdEnvVars.keys.toSeq

proc main() =
  let
    confData = readConfigFiles()
    versionSpec =
      if paramCount() > 0:
        paramStr(1)
      else:
        ""
  confData.sort()

  let
    versionOpts = confData.getVersionOpts(versionSpec)
    versionSpec1 = confData.getVersionSpec(versionSpec)
    cmdBinPath = confData.paths.getPath(versionSpec1)
    cmdSwitches = confData.switches.get(versionSpec1)
    cmdEnvVars = confData.envs.get(versionSpec1)
  echo ""
  echo "versionOpts: ", versionOpts
  echo "versionSpec1: ", versionSpec1
  echo "cmdBinPath: ", cmdBinPath
  echo "cmdSwitches: ", cmdSwitches
  echo "cmdEnvVars: ", cmdEnvVars

when isMainModule:
  main()
