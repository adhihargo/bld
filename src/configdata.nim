import std/json
import std/options
import std/tables
import jsonschema

jsonSchema:
  ConfigSchema:
    paths ?: any
    switches ?: any
    envs ?: any

type
  ConfigData* = object
    paths*: OrderedTable[string, string]
    switches*: OrderedTable[string, string]
    envs*: OrderedTable[string, OrderedTable[string, seq[string]]]

proc isValidConfig*(jsonNode: JsonNode): bool =
  return isValid(jsonNode, ConfigSchema)
