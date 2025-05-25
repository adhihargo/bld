import std/algorithm
import std/os
import std/sequtils
import std/strutils
import std/sugar
import std/tables

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
): string =
  let
    ctxTblPaths: OrderedTable[string, string] = getVersionTable(versionSpec, tblPaths)
    tblPathsKeys = ctxTblPaths.keys.toSeq.sorted(order = SortOrder.Descending)
  for k in tblPathsKeys:
    if fileExists(ctxTblPaths[k]):
      return k

proc getCommandBinPath*(
    versionSpec: string, tblPaths: OrderedTable[string, string]
): string =
  return tblPaths.getOrDefault(versionSpec)

proc getCommandSwitches*(
    versionSpec: string, tblSwitches: OrderedTable[string, string]
): string =
  let
    ctxTblSwitches = getVersionTable(versionSpec, tblSwitches, true)
    tblSwitchesKeys = ctxTblSwitches.keys.toSeq.sorted(order = SortOrder.Descending)
  for k in tblSwitchesKeys:
    return ctxTblSwitches[k]

proc getCommandEnvVars*(
    versionSpec: string, tblEnvVars: OrderedTable
): OrderedTable[string, seq[string]] {.inline.} =
  let
    ctxTblEnvVars = getVersionTable(versionSpec, tblEnvVars, true)
    tblEnvVarsKeys = ctxTblEnvVars.keys.toSeq.sorted(order = SortOrder.Descending)
  for k in tblEnvVarsKeys:
    return ctxTblEnvVars[k]
