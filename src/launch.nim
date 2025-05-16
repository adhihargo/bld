import std/algorithm
import std/osproc
import std/sequtils
import std/strutils
import std/sugar
import std/tables

import args
import cmds
import config
import configdata
import envvars
import errors
import fileid

proc getArgData(): ref ArgumentsData =
  try:
    result = parseArgs()
  except CommandLineError as e:
    stderr.writeLine("> Command line error: ", e.msg)
    quit(QuitFailure)

proc processExeArgs(exeArgList: seq[string]) =
  if exeArgList.len == 0:
    return

  let exeTable = collect(initOrderedTable):
    for exePath in exeArgList:
      let exeVersion = getBlenderExeVersion(exePath)
      if exeVersion != "":
        {exeVersion: exePath}
  if exeTable.len > 0:
    stderr.writeLine("> Registering Blender versions: ")
    for v in exeTable.keys:
      stderr.writeLine("> -v:", v)
    editConfigFile(exeTable)
    quit(QuitSuccess)
  else:
    stderr.writeLine("> No recognized Blender binary in argument list, exiting.")
    quit(QuitFailure)

proc runApp() =
  let
    argData = getArgData()
    confData = readConfig(argData.configPath)
    versionOpts = getVersionOpts(argData.versionSpec, confData.paths)

  if argData.commandType == cmdList:
    stderr.writeLine("> Blender versions registered:")
    for v in versionOpts:
      stderr.writeLine("> -v:", v)
    quit(QuitSuccess)

  # check and register executables passed as arguments.
  let exeArgList = getArgsExeList(argData.filePathList)
  processExeArgs(exeArgList)

  if versionOpts.len == 0:
    stderr.writeLine("> No available version specs, exiting")
    quit(QuitFailure)

  let versionSpec = getVersionSpec(argData.versionSpec, confData.paths)
  if versionSpec == "":
    var versionOptsStr = join(versionOpts, ", ")
    stderr.writeLine("> Invalid version spec: ", argData.versionSpec)
    stderr.writeLine("> Available version specs: ", versionOptsStr)
    quit(QuitFailure)

  let
    cmdBinPath = getCommandBinPath(versionSpec, confData.paths)
    cmdSwitches = getCommandSwitches(argData.versionSpec, confData.switches)
    cmdEnvVars = getCommandEnvVars(argData.versionSpec, confData.envs)
  applyEnvVars(cmdEnvVars)

  let cmdStr = [cmdBinPath, argData.passedArgs, cmdSwitches].join(" ")
  stderr.writeLine("> Command: ", cmdStr)
  discard execCmd(cmdStr)

when isMainModule:
  runApp()
