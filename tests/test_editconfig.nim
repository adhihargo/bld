include editconfig

import errors

import std/unittest

test "Attempt to update nonexistent config file":
  let confPath = "nonexistent.json"
  expect ConfigError:
    updateConfigPaths(confPath)

test "Append binary path to new file":
  let
    binList = @["C:\\prog\\blender-2.93.18-windows-x64\\blender.exe"]
    binTable = getBlenderExeVersionTable(binList)
    confPath = os.getCurrentDir() / "editconfig.json"

  if confPath.fileExists:
    echo "Removing test config file"
    confPath.removeFile()

  appendConfigPaths(binTable, confPath)
