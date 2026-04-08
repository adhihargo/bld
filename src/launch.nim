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
import editconfig
import cmdtable
import config
import configdata
import constants
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

proc processExePaths(exeArgList: seq[string]) =
  if exeArgList.len == 0:
    return

  let exeTable = getBlenderExeVersionTable(exeArgList)
  if exeTable.len > 0:
    appendConfigPaths(exeTable)
    quit(QuitSuccess)
  else:
    stderr.writeLine("> No recognized Blender binary in argument list, exiting.")
    quit(QuitFailure)

proc processCommandExec(
  versionSpec: VersionSpec,
  confData: ref ConfigData,
  filePath: string,
  passedArgs: string,
)

proc processBlendArgs(
    blendArgList: seq[string],
    versionSpec: VersionSpec,
    confData: ref ConfigData,
    passedArgs: string,
) =
  if blendArgList.len == 0:
    return

  let
    tblPaths = confData.paths
    latestVersionSpec = confData.getVersionSpec()
    fileVersionTable = getBlenderFileVersionTable(blendArgList, confData)
    verTripletOpts = tblPaths.keys.toSeq.map(
      proc(key: string): (VersionTriplet, string, string) =
        let optVerTriplet = key.readVersionTriplet
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
      processCommandExec(latestVersionSpec, confData, filePath, passedArgs)
      break
    let fileVersion = optFileVersion.get()
    for vTuple in verTripletOpts:
      if vTuple[0] >= fileVersion and vTuple[2].fileExists:
        let versionSpec = confData.getVersionSpec(vTuple[1])
        stderr.writeLine("> File version: ", fileVersion)
        processCommandExec(versionSpec, confData, filePath, passedArgs)
        break
    # fallthrough (file made with version newer than any available), open with latest
    processCommandExec(latestVersionSpec, confData, filePath, passedArgs)
    break

proc processCommandExec(
    versionSpec: VersionSpec,
    confData: ref ConfigData,
    filePath: string,
    passedArgs: string,
) =
  let versionSpecStr =
    if versionSpec.matching == "":
      versionSpec.literal
    else:
      versionSpec.literal & "/" & versionSpec.matching

  var cmdStr = ""
  try:
    let
      cmdBinPath = confData.paths.getPath(versionSpec)
      cmdSwitches = confData.switches.get(versionSpec)
      cmdEnvVars = confData.envs.get(versionSpec).finalizeEnvVars
      filePath = if filePath == "": filePath else: filePath.quoteShell
    applyEnvVars(versionSpec, cmdEnvVars)
    cmdStr = [cmdBinPath, filePath, cmdSwitches, passedArgs]
      .filter(
        proc(c: string): bool =
          c != ""
      )
      .join(" ")
  except ConfigError as e: # catch finalizeEnvVars erros
    stderr.writeLine(&"> Config error [v{versionSpecStr}]: ", e.msg)
    quit(QuitFailure)

  stderr.writeLine(&"> Command [v{versionSpecStr}]: ", $cmdStr)
  discard execCmd(cmdStr)
  quit(QuitSuccess)

proc runApp() =
  let
    argData = getArgData()
    blendArgList = getArgsBlendList(argData.filePathList)
  var configPathList = argData.configPathList
  if blendArgList.len > 0:
    configPathList.add(
      findAtPathHierarchy(@[CONFIG_JSON_NAME, CONFIG_YAML_NAME], blendArgList[0])
    )

  let
    confData = readConfigFiles(configPathList)
    versionOpts = confData.getVersionOpts(argData.versionSpec)
  confData.sort()

  if argData.commandType == cmtUpdatePaths:
    stderr.writeLine("> Updating Blender versions list")
    updateConfigPaths()
    quit(QuitSuccess)
  elif argData.commandType == cmtList:
    stderr.writeLine("> Blender versions registered:")
    for v in versionOpts:
      stderr.writeLine("> -v:", v)
    quit(QuitSuccess)
  elif argData.commandType == cmtInstall:
    stderr.writeLine("> Registering self to handle .blend files")
    let binPath = getAppFilename()
    if registerExtHandler(binPath, argData.passedArgs):
      stderr.writeLine("> Handler registration succeeded")
      quit(QuitSuccess)
    else:
      stderr.writeLine("> Handler registration failed")
      quit(QuitFailure)
  elif argData.commandType == cmtPrintConf:
    stderr.writeLine("> Configuration data:")
    stderr.writeLine($confData)
    quit(QuitSuccess)

  # check and register executables passed as arguments.
  let exeArgList = getArgsExeList(argData.filePathList)
  processExePaths(exeArgList)

  if versionOpts.len == 0:
    stderr.writeLine("> No available version specs, exiting")
    quit(QuitFailure)

  let versionSpec = confData.getVersionSpec(argData.versionSpec)
  if versionSpec == nil:
    var versionOptsStr = join(versionOpts, ", ")
    stderr.writeLine("> Invalid version spec: ", argData.versionSpec)
    stderr.writeLine("> Available version specs: ", versionOptsStr)
    quit(QuitFailure)

  # passed blend file arguments directly, call each with appropriate
  # Blender version if available.
  if blendArgList.len > 0:
    processBlendArgs(blendArgList, versionSpec, confData, argData.passedArgs)
  else:
    processCommandExec(versionSpec, confData, "", argData.passedArgs)

when isMainModule:
  runApp()
