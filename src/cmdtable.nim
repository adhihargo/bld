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
  ## String conversion operator for version spec

  if versionSpec == nil:
    result = "nil"
  else:
    result = "VersionSpec(literal: "
    result.addQuoted(versionSpec.literal)
    result.add(", matching: ")
    result.addQuoted(versionSpec.matching)
    result.add(")")

proc `==`*(a, b: VersionSpec): bool =
  ## Equality operator for version specs

  return
    (a.isNil and b.isNil) or
    (not (a.isNil or b.isNil) and a.literal == b.literal and a.matching == b.matching)

proc getVersionTable(
    versionSpec: string, table: OrderedTable, reverse: bool = false
): OrderedTable {.inline.} =
  ## Return a subset of `table` with keys that `versionSpec` is a
  ## substring of or, if `reverse` is true (to aid cross-referencing),
  ## with keys that are substrings of `versionSpec`.

  let emptyVersionSpec = versionSpec.strip() == ""
  return collect(initOrderedTable()):
    for k, v in table.pairs:
      if emptyVersionSpec or (
        not emptyVersionSpec and
        ((reverse and versionSpec.startsWith(k)) or k.startsWith(versionSpec))
      ):
        {k: v}

proc getVersionOpts*(confData: ref ConfigData, versionSpec: string): seq[string] =
  ## Get a list of available version specs matching `versionSpec`

  let
    tblPaths = confData.paths
    ctxTblPaths = getVersionTable(versionSpec, tblPaths)
  return ctxTblPaths.keys.toSeq

proc getVersionSpec*(confData: ref ConfigData, versionSpec: string = ""): VersionSpec =
  ## Get a version spec pointing to an existing binary path, matching
  ## `versionSpec` literally or by cross-reference. By default should
  ## return version spec of numerically latest (or explicitly default)
  ## binary path.

  let
    tblPaths = confData.paths
    litTableKeys = confData.getVersionOpts(versionSpec).sorted(order = SortOrder.Descending)
  for k in litTableKeys:
    let v = tblPaths[k]
    if fileExists(v):
      return VersionSpec(literal: k)
    elif versionSpec != "":
      # version spec cross reference
      let versionSpec2 = confData.getVersionSpec(v)
      if versionSpec2 != nil and fileExists(tblPaths[versionSpec2.literal]):
        return VersionSpec(literal: k, matching: versionSpec2.literal)

proc getPath*(tblPaths: PathTable, versionSpec: VersionSpec): string =
  doAssert versionSpec != nil, "Version spec must be provided"

  let binPath = tblPaths.getOrDefault(versionSpec.matching)
  return
    if binPath != "":
      binPath
    else:
      tblPaths.getOrDefault(versionSpec.literal)

template getByVersionSpec(versionSpecStr, table) =
  let
    lTable = getVersionTable(versionSpecStr, table, true)
    lTableKeys = lTable.keys.toSeq.sorted(order = SortOrder.Descending)
  for k in lTableKeys:
    return lTable[k]

proc get*(table: PathTable, versionSpec: VersionSpec): string =
  doAssert versionSpec != nil, "Version spec must be provided"

  getByVersionSpec(versionSpec.literal, table)
  if versionSpec.matching != "":
    getByVersionSpec(versionSpec.matching, table)

proc get*(table: OrderedTable, versionSpec: VersionSpec): EnvVarMapping =
  doAssert versionSpec != nil, "Version spec must be provided"

  getByVersionSpec(versionSpec.literal, table)
  if versionSpec.matching != "":
    getByVersionSpec(versionSpec.matching, table)
