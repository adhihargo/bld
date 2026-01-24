include configyaml

import std/tables

import constants

proc main() =
  var confData: ref ConfigData
  try:
    confData = readConfigYAML(CONFIG_YAML_NAME)
  except ConfigError as e:
    stderr.writeLine("> Config error: ", e.msg)
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
