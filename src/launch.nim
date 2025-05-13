import std/algorithm
import std/os
import std/osproc
import std/sequtils
import std/strutils
import std/sugar
import std/tables

import args
import config
import configdata
import envvars
import errors

proc getArgData(): ref ArgumentsData =
  try:
    result = parseArgs()
  except CommandLineError as e:
    stderr.writeLine("> Command line error: ", e.msg)
    quit(QuitFailure)

proc getVersionTable(
    versionSpec: string, tblPaths: OrderedTable[string, string]
): OrderedTable[string, string] {.inline.} =
  return
    if versionSpec == "":
      tblPaths
    else:
      collect(initOrderedTable()):
        for k, v in tblPaths.pairs:
          if k.startsWith(versionSpec):
            {k: v}

proc getVersionOpts(
    versionSpec: string, tblPaths: OrderedTable[string, string]
): seq[string] =
  let ctxTblPaths: OrderedTable[string, string] = getVersionTable(versionSpec, tblPaths)
  return ctxTblPaths.keys.toSeq

proc getVersionSpec(
    versionSpec: string, tblPaths: OrderedTable[string, string]
): string =
  let ctxTblPaths: OrderedTable[string, string] = getVersionTable(versionSpec, tblPaths)
  for k in reversed(ctxTblPaths.keys.toSeq):
    if fileExists(ctxTblPaths[k]):
      return k

proc processCommandStr(
    versionSpec: string, passedArgs: string, confData: ref ConfigData
): string =
  let
    binPath = confData.paths.getOrDefault(versionSpec)
    cmdSwitches = confData.switches.getOrDefault(versionSpec)
  if not fileExists(binPath):
    stderr.writeLine("> Nonexistent binary path: ", binPath)
  return [binPath, passedArgs, cmdSwitches].join(" ")

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

  if versionOpts.len == 0:
    stderr.writeLine("> No available version specs, exiting")
    quit(QuitFailure)

  var versionSpec = getVersionSpec(argData.versionSpec, confData.paths)
  if versionSpec == "":
    var versionSpecOpts = join(versionOpts, ", ")
    stderr.writeLine("> Invalid version spec: ", argData.versionSpec)
    stderr.writeLine("> Available version specs: ", versionSpecOpts)
    quit(QuitFailure)

  let versionEnvVars = confData.envs.getOrDefault(versionSpec)
  applyEnvVars(versionEnvVars)

  let cmdStr = processCommandStr(versionSpec, argData.passedArgs, confData)
  stderr.writeLine("> Command: ", cmdStr)
  discard execCmd(cmdStr)

when isMainModule:
  runApp()
