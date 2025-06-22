import std/algorithm
import std/os
import std/sequtils
import std/strutils
import std/sugar
import std/tables

type VersionSpec* = ref object
  literal*: string
  matching*: string

proc `$`*(versionSpec: VersionSpec): string =
  if versionSpec == nil:
    result = "nil"
  else:
    result = "VersionSpec(literal: "
    result.addQuoted(versionSpec.literal)
    result.add(", matching: ")
    result.addQuoted(versionSpec.matching)
    result.add(")")

proc `==`*(a, b: VersionSpec): bool =
  return
    (a.isNil and b.isNil) or
    (not (a.isNil or b.isNil) and a.literal == b.literal and a.matching == b.matching)

proc getVersionTable*(
    versionSpec: string, tblPaths: OrderedTable, reverse: bool = false
): OrderedTable {.inline.} =
  return
    if versionSpec == "":
      tblPaths
    else:
      collect(initOrderedTable()):
        for k, v in tblPaths.pairs:
          if (reverse and versionSpec.startsWith(k)) or k.startsWith(versionSpec):
            {k: v}

proc getVersionOpts*(
    versionSpec: string, tblPaths: OrderedTable[string, string]
): seq[string] =
  let ctxTblPaths: OrderedTable[string, string] = getVersionTable(versionSpec, tblPaths)
  return ctxTblPaths.keys.toSeq

proc getVersionSpec*(
    versionSpec: string, tblPaths: OrderedTable[string, string]
): VersionSpec =
  let
    ctxTblPaths: OrderedTable[string, string] = getVersionTable(versionSpec, tblPaths)
    tblPathsKeys = ctxTblPaths.keys.toSeq.sorted(order = SortOrder.Descending)
  for k in tblPathsKeys:
    let kBinPath = ctxTblPaths[k]
    if fileExists(kBinPath):
      return VersionSpec(literal: k)

proc getCommandBinPath*(
    versionSpec: VersionSpec, tblPaths: OrderedTable[string, string]
): string =
  return tblPaths.getOrDefault(versionSpec.literal)

proc getCommandSwitches*(
    versionSpec: VersionSpec, tblSwitches: OrderedTable[string, string]
): string =
  let
    ctxTblSwitches = getVersionTable(versionSpec.literal, tblSwitches, true)
    tblSwitchesKeys = ctxTblSwitches.keys.toSeq.sorted(order = SortOrder.Descending)
  for k in tblSwitchesKeys:
    return ctxTblSwitches[k]

proc getCommandEnvVars*(
    versionSpec: VersionSpec, tblEnvVars: OrderedTable
): OrderedTable[string, seq[string]] {.inline.} =
  let
    ctxTblEnvVars = getVersionTable(versionSpec.literal, tblEnvVars, true)
    tblEnvVarsKeys = ctxTblEnvVars.keys.toSeq.sorted(order = SortOrder.Descending)
  for k in tblEnvVarsKeys:
    return ctxTblEnvVars[k]

when isMainModule:
  import config
  import configdata

  let
    confData = readConfig()
    versionSpec =
      if paramCount() > 0:
        paramStr(1)
      else:
        ""
  confData.sort()

  let
    versionOpts = getVersionOpts(versionSpec, confData.paths)
    versionSpec1 = getVersionSpec(versionSpec, confData.paths)
    cmdBinPath = getCommandBinPath(versionSpec1, confData.paths)
    cmdSwitches = getCommandSwitches(versionSpec1, confData.switches)
    cmdEnvVars = getCommandEnvVars(versionSpec1, confData.envs)
  echo ""
  echo "versionOpts: ", versionOpts
  echo "versionSpec1: ", versionSpec1
  echo "cmdBinPath: ", cmdBinPath
  echo "cmdSwitches: ", cmdSwitches
  echo "cmdEnvVars: ", cmdEnvVars
