include scriptdir

import std/unittest

let currentDir = getCurrentDir()

test "Variable with suffix for scripts directory":
  let
    scriptPath = currentDir / "test_scriptdir_scripts"
    addonsPath = scriptPath / "addons"
  check:
    verifyScriptDir("BLENDER_USER_SCRIPTS", scriptPath)
    dirExists(addonsPath)

test "Variable with suffix for config directory":
  let
    configPath = currentDir / "test_scriptdir_config"
    addonsPath = configPath / "addons"
  check:
    verifyScriptDir("BLENDER_USER_CONFIG", configPath)
    not dirExists(addonsPath)

test "Other variable name suffix":
  let nonexistentPath = currentDir / "nonexistent_path"
  check:
    verifyScriptDir("ANYVALUE", nonexistentPath)
    not dirExists(nonexistentPath)
