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

proc getVersionTable*(
    versionSpec: string, tblPaths: OrderedTable, reverse: bool = false
): OrderedTable {.inline.} =
  let emptyVersionSpec = versionSpec.strip() == ""
  return collect(initOrderedTable()):
    for k, v in tblPaths.pairs:
      if emptyVersionSpec or (
        not emptyVersionSpec and
        ((reverse and versionSpec.startsWith(k)) or k.startsWith(versionSpec))
      ):
        {k: v}

proc getVersionOpts*(versionSpec: string, tblPaths: PathTable): seq[string] =
  let ctxTblPaths: PathTable = getVersionTable(versionSpec, tblPaths)
  return ctxTblPaths.keys.toSeq

proc getVersionSpec*(versionSpec: string, tblPaths: PathTable): VersionSpec =
  let
    litTable = getVersionTable(versionSpec, tblPaths)
    litTableKeys = litTable.keys.toSeq.sorted(order = SortOrder.Descending)
  for k in litTableKeys:
    let v = litTable[k]
    if fileExists(v):
      return VersionSpec(literal: k)
    elif versionSpec != "":
      # version spec cross reference
      let versionSpec2 = getVersionSpec(v, tblPaths)
      if versionSpec2 != nil and fileExists(tblPaths[versionSpec2.literal]):
        return VersionSpec(literal: k, matching: versionSpec2.literal)

proc getCommandBinPath*(versionSpec: VersionSpec, tblPaths: PathTable): string =
  let binPath = tblPaths.getOrDefault(versionSpec.matching)
  return
    if binPath != "":
      binPath
    else:
      tblPaths.getOrDefault(versionSpec.literal)

proc getCommandSwitches*(versionSpec: VersionSpec, table: PathTable): string =
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
    confData = readConfigFiles()
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
