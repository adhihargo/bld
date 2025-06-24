import std/algorithm
import std/os
import std/sequtils
import std/strutils
import std/sugar
import std/tables

import configdata

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

proc versionValueFilter(v: EnvVarMapping): bool =
  true

proc versionValueFilter(v: string): bool =
  fileExists(v)

proc getVersionTable*(
    versionSpec: string, tblPaths: OrderedTable, reverse: bool = false
): OrderedTable {.inline.} =
  let emptyVersionSpec = versionSpec.strip() == ""
  return collect(initOrderedTable()):
    for k, v in tblPaths.pairs:
      if (emptyVersionSpec and versionValueFilter(v)) or (
        not emptyVersionSpec and
        ((reverse and versionSpec.startsWith(k)) or k.startsWith(versionSpec))
      ):
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
    ctxTblPathsKeys = ctxTblPaths.keys.toSeq.sorted(order = SortOrder.Descending)
  for k in ctxTblPathsKeys:
    let kBinPath = ctxTblPaths[k]
    if kBinPath in tblPaths.keys.toSeq and fileExists(tblPaths.getOrDefault(kBinPath)):
      # version spec cross reference
      return VersionSpec(literal: k, matching: kBinPath)
    elif fileExists(kBinPath):
      return VersionSpec(literal: k)

proc getCommandBinPath*(
    versionSpec: VersionSpec, tblPaths: OrderedTable[string, string]
): string =
  let binPath = tblPaths.getOrDefault(versionSpec.matching)
  return
    if binPath != "":
      binPath
    else:
      tblPaths.getOrDefault(versionSpec.literal)

proc getCommandSwitches*(
    versionSpec: VersionSpec, table: OrderedTable[string, string]
): string =
  let
    litTable = getVersionTable(versionSpec.literal, table, true)
    litTableKeys = litTable.keys.toSeq.sorted(order = SortOrder.Descending)
  for k in litTableKeys:
    return litTable[k]

  if versionSpec.matching != "":
    let
      matTable = getVersionTable(versionSpec.matching, table, true)
      matTableKeys = matTable.keys.toSeq.sorted(order = SortOrder.Descending)
    for k in matTableKeys:
      return matTable[k]

proc getCommandEnvVars*(
    versionSpec: VersionSpec, table: OrderedTable
): EnvVarMapping {.inline.} =
  let
    litTable = getVersionTable(versionSpec.literal, table, true)
    litTableKeys = litTable.keys.toSeq.sorted(order = SortOrder.Descending)
  for k in litTableKeys:
    return litTable[k]

  if versionSpec.matching != "":
    let
      matTable = getVersionTable(versionSpec.matching, table, true)
      matTableKeys = matTable.keys.toSeq.sorted(order = SortOrder.Descending)
    for k in matTableKeys:
      return matTable[k]

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
