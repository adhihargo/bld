import std/algorithm
import std/options
import std/os
import std/osproc
import std/sequtils
import std/strutils
import std/strformat
import std/sugar
import std/tables

import args
import cmdtable
import config
import configdata
import envvars
import errors
import fileid
import registry

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

proc processCommandExec(
  versionSpec: string, confData: ref ConfigData, filePath: string, passedArgs: string
)

proc processBlendArgs(
    blendArgList: seq[string],
    versionSpec: string,
    confData: ref ConfigData,
    passedArgs: string,
) =
  if blendArgList.len == 0:
    return

  let
    tblPaths = confData.paths
    fileVersionTable = getBlenderFileVersionTable(blendArgList, tblPaths)
    verTripletOpts = tblPaths.keys.toSeq.map(
      proc(key: string): (VersionTriplet, string, string) =
        let optVerTriplet = key.toVersionTriplet
        let verTriplet =
          if optVerTriplet.isNone:
            [-1, -1, -1]
          else:
            optVerTriplet.get()
        (verTriplet, key, tblPaths[key])
    )
  for filePath in blendArgList:
    let optFileVersion = fileVersionTable.getOrDefault(filePath)
    if optFileVersion.isNone:
      # unknown file version, open with latest available
      processCommandExec("", confData, filePath, passedArgs)
      break
    for vTuple in verTripletOpts:
      let fileVersion = optFileVersion.get()
      if vTuple[0] >= fileVersion and vTuple[2].fileExists:
        let versionSpec = vTuple[1]
        stderr.writeLine("> File version: ", fileVersion)
        processCommandExec(versionSpec, confData, filePath, passedArgs)
        break

proc processCommandExec(
    versionSpec: string, confData: ref ConfigData, filePath: string, passedArgs: string
) =
  var cmdStr = ""
  try:
    let
      cmdBinPath = getCommandBinPath(versionSpec, confData.paths)
      cmdSwitches = getCommandSwitches(versionSpec, confData.switches)
      cmdEnvVars = getCommandEnvVars(versionSpec, confData.envs).finalizeEnvVars
      filePath = if filePath == "": filePath else: filePath.quoteShell
    applyEnvVars(cmdEnvVars)
    cmdStr = [cmdBinPath, filePath, passedArgs, cmdSwitches]
      .filter(
        proc(c: string): bool =
          c != ""
      )
      .join(" ")
  except ConfigError as e: # catch finalizeEnvVars erros
    stderr.writeLine(&"> Config error [v{versionSpec}]: ", e.msg)
    quit(QuitFailure)

  stderr.writeLine(&"> Command [v{versionSpec}]: ", $cmdStr)
  discard execCmd(cmdStr)
  quit(QuitSuccess)

proc runApp() =
  let
    argData = getArgData()
    confData = readConfig(argData.configPathList)
    versionOpts = getVersionOpts(argData.versionSpec, confData.paths)
  confData.sort()

  if argData.commandType == cmdList:
    stderr.writeLine("> Blender versions registered:")
    for v in versionOpts:
      stderr.writeLine("> -v:", v)
    quit(QuitSuccess)
  elif argData.commandType == cmdInstall:
    stderr.writeLine("> Registering self to handle .blend files")
    let binPath = getAppFilename()
    if registerExtHandler(binPath, argData.passedArgs):
      stderr.writeLine("> Handler registration succeeded")
      quit(QuitSuccess)
    else:
      stderr.writeLine("> Handler registration failed")
      quit(QuitFailure)
  elif argData.commandType == cmdPrintConf:
    stderr.writeLine("> Configuration data:")
    stderr.writeLine($confData)
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

  # passed blend file arguments directly, call each with appropriate
  # Blender version if available.
  let blendArgList = getArgsBlendList(argData.filePathList)
  if blendArgList.len > 0:
    processBlendArgs(blendArgList, versionSpec, confData, argData.passedArgs)
  else:
    processCommandExec(versionSpec, confData, "", argData.passedArgs)

when isMainModule:
  runApp()
