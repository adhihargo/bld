import std/os
import std/parseopt
import std/strformat
import std/strutils

import errors

type
  CommandType* = enum
    cmdExec
    cmdList
    cmdPrintConf
    cmdRegister

  ArgumentsData* = object
    help: bool
    commandType*: CommandType
    versionSpec*: string
    filePathList*: seq[string]
    configPathList*: seq[string]
    passedArgs*: string

onFailedAssert(msg):
  var submsg = msg
  submsg = msg.substr(max(0, msg.rfind("` ") + 2))
  raise (ref CommandLineError)(msg: submsg)

proc printHelp() =
  let binName = lastPathPart(getAppFilename())
  echo &"{binName} FILE_ARG --v:VERSION_SPEC -c:CONFIG_PATH* FILE_ARG* - \n"
  echo """
FILE_ARG*		Any number of file arguments. Ones
			without .blend* extension assumed to
			be executables and will be
			registered into available executable
			paths.
-v:VERSION_SPEC		Specify version spec as listed as a
			key in config file's 'paths' section.
-c/--conf=CONFIG_PATH	Specify config file path,
			repeatable. This overrides default
			behavior of sequentially reading
			predefined config file paths.
-l/--list		List all version specs registered
			for the launcher, or if -v is used,
			ones prefixed with VERSION_SPEC.
--print-conf		Print accumulated configuration
			data.
--register		[WINDOWS] Register this executable
			as default handler for .blend files.
-h/--help		Print help, then exit.
-/--			First occurence ends command line
			parsing. Remaining arguments will be
			passed to Blender process being
			called.
"""

proc parseArgsRaw(): ref ArgumentsData =
  var p = initOptParser(
    shortNoVal = {'h', 'l'}, longNoVal = @["help", "list", "print-conf", "register", ""]
  )

  result = (ref ArgumentsData)(commandType: cmdExec)
  while true:
    p.next()
    if p.kind == cmdEnd:
      break

    if p.kind in {cmdShortOption, cmdLongOption} and p.key == "":
      result.passedArgs = p.cmdLineRest
      break
    elif p.key in ["v"]:
      result.versionSpec = p.val
    elif p.key in ["c", "conf"]:
      doAssert p.val != "", "-c/--conf needs filepath argument"
      result.configPathList.add(p.val)
    elif p.key in ["l", "list"]:
      result.commandType = cmdList
    elif p.key in ["h", "help"]:
      result.help = true
    elif p.key in ["print-conf"]:
      result.commandType = cmdPrintConf
    elif p.key in ["register"]:
      result.commandType = cmdRegister
    elif p.kind == cmdArgument:
      result.filePathList.add(p.key)
    else:
      raise newException(CommandLineError, "Unrecognized flag: " & p.key)

proc parseArgs*(): ref ArgumentsData =
  let argData = parseArgsRaw()
  if argData != nil and argData.help:
    printHelp()
    quit(QuitSuccess)
  else:
    return argData

when isMainModule:
  import marshal

  var argData: ref ArgumentsData
  try:
    argData = parseArgs()
  except CommandLineError as e:
    echo "> Commandline error: ", e.msg

  echo "argData: ", $$argData
