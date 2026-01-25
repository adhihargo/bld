include config

import std/unittest

proc main() =
  let confData = readConfigFiles()
  echo "confData: ", confData

when isMainModule:
  main()
