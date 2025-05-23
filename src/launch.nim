import std/algorithm
import std/options
import std/os
import std/osproc
import std/sequtils
import std/strutils
import std/sugar
import std/tables

import args
import cmdtable
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

proc processBlendArgs(blendArgList: seq[string], tblPaths: PathTable) =
  if blendArgList.len == 0:
    return

  let
    fileVersionList = getBlenderFileVersionList(blendArgList, tblPaths)
    verTripletPaths = tblPaths.pairs.toSeq.map(
      proc(vPair: (string, string)): (VersionTriplet, string, string) =
        let optVerTriplet = vPair[0].toVersionTriplet
        let verTriplet =
          if optVerTriplet.isNone:
            [-1, -1, -1]
          else:
            optVerTriplet.get()
        (verTriplet, vPair[0], vPair[1])
    ).sortedByIt((it[0][0], it[0][1], it[0][2]))
  for fPair in fileVersionList:
    for vPair in verTripletPaths:
      if vPair[0] >= fPair[0]:
        let
          cmdBinPath = vPair[2]
          cmdStr = [cmdBinPath, fPair[1]].quoteShellCommand
        stderr.writeLine("> Command: ", cmdStr)
        discard execCmd(cmdStr)
        break

  quit(QuitSuccess)

proc runApp() =
  let
    argData = getArgData()
    confData = readConfig(argData.configPath)
    versionOpts = getVersionOpts(argData.versionSpec, confData.paths)
  confData.sort()

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

  # passed blend file arguments directly, call each with appropriate
  # Blender version if available.
  let blendArgList = getArgsBlendList(argData.filePathList)
  processBlendArgs(blendArgList, confData.paths)

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
