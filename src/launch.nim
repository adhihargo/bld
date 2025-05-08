import std/algorithm
import std/os
import std/osproc
import std/sequtils
import std/strutils
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

proc getMatchingVersionOpts(
    versionSpec: string, versionOpts: seq[string]
): seq[string] {.inline.} =
  return filter(
    toOpenArray(versionOpts, 0, versionOpts.high),
    proc(v: string): bool =
      v.startsWith(versionSpec),
  )

proc processVersionSpec(versionSpec: string, versionOpts: seq[string]): string =
  if versionSpec == "":
    result = versionOpts[versionOpts.high]
  elif not (versionSpec in versionOpts):
    let matchingVersionOpts = getMatchingVersionOpts(versionSpec, versionOpts)
    if matchingVersionOpts.len > 0:
      result = matchingVersionOpts[matchingVersionOpts.high]

proc processCommandStr(versionSpec: string, passedArgs: string, confData: ref ConfigData): string =
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
    versionOpts = sorted(confData.paths.keys.toSeq)

  if argData.commandType == cmdList:
    let matchingVersionOpts = getMatchingVersionOpts(argData.versionSpec, versionOpts)
    stderr.writeLine("> Blender versions registered:")
    for v in matchingVersionOpts:
      stderr.writeLine("> -v:", v)
    quit(QuitSuccess)

  if versionOpts.len == 0:
    stderr.writeLine("> No available version specs, exiting")
    quit(QuitFailure)

  var versionSpec = processVersionSpec(argData.versionSpec, versionOpts)
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
