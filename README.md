`bld` is an experiment in making a Blender launcher flexible enough to accomodate various purposes through as many versions as possible.

## Use Cases

The intention is to write a tool that,

- With at least one config file, simplify setting up several different environments with their own sets of user preferences, installed addons, etc.
- Use separate user preferences per group of Blender versions.
- Use separate sets of addons per intended task (modeling, rigging, animating, etc.)
- Open any Blender file with the most compatible version available.
- Easier setup of portable, per-project Blender configuration.

# Getting Started

1. Download and extract `bld`'s binary archive in any location. The next steps assume that location is included in `PATH` environment variable, otherwise run in a command shell or file manager window pointing to its directory.
2. Register at least one Blender executable either by drag and drop to `bld` executable in file manager, or run `bld` in command shell with the executables' full path as arguments. An even faster way is to search for all `blender.exe` files in any file manager or tools like [voidtools' Everything](https://www.voidtools.com/), then drag them into `bld`. This will create `bld.json` in home directory (see [Configuration Files](#configfiles)).
   Later installations, if placed under the same parent directory as previously registered, can be quickly added by running
   
   ```shell
   bld --update
   ```
   
   To read more about this operation, see [Version List Update](#listupdate).
3. To install `bld` as default handler for `.blend` files, run this command in terminal or through Run dialog:
   ```shell
   bld --install
   ```
4. Create a `bld.yaml` config file to set run options for each executables added.

# Command Line Arguments<a id="cmdargs"/>

Usage:

```shell
bld FILE_ARG* --v:VERSION_SPEC -c:CONFIG_PATH* FILE_ARG* -
```

| Argument/switch                 | Description                                                  |
| ------------------------------- | ------------------------------------------------------------ |
| `FILE_ARG` | Any number of file arguments. Ones without `.blend*` extension assumed to be executables and will be added into available executable paths. |
| `-v:VERSION_SPEC` | Specify version spec as listed as a key in config file's `'paths'` section. |
| `-u`/`--update` | Updates executable path list. Parent directory of all listed paths will be searched for other files named `blender.exe` at the same level. Newly-found paths added, nonexistent paths removed. |
| `-c`/<br />`--conf=CONFIG_PATH` | Specify config file path, repeatable. These paths will be read after predefined config file paths. |
| `-l`/`--list` | List all version specs registered for the launcher, or if `-v` is used, ones prefixed with `VERSION_SPEC`. |
| `--print-conf` | Print accumulated configuration data. |
| `--install` | **[WND]** Register this executable as default handler for `.blend` files. Arguments passed after `-`/`--` will be added in the resulting `bld` command. |
| `-h`/`--help` | Print help, then exit. |
| `-`/`--` | First occurence ends command line parsing. Remaining arguments will be passed to Blender process being called. |

## Reading `.blend` File Version

To minimize issues caused by opening a file with an incompatible Blender version, `bld` attempts to read file version of each `.blend` files passed as its arguments. It does this simply by running those files through a Python script printing their version, using the latest listed Blender executable.

In cases where Blender failed to read file version, `bld` simply use the latest version listed. If one of the files crashed the Blender executable being used, others will be listed as failed to read, too, where they can otherwise be read without issue.

This behavior can be bypassed simply by passing file path arguments after `-` (or `--`) command line switch.

# Configuration Files<a id="configfiles"/>

`bld` reads config files in both JSON and YAML format of equivalent structure, from:

1. Files read sequentially in a specific order (default behavior):
   1. `~/bld.json` (home directory)
   1. `~/bld.yaml`
   1. `./bld.json` (directory of `bld` executable)
   1. `./bld.yaml`

2. One or more files explicitly passed as command line arguments (see `-c` in [*Command Line Arguments*](#cmdargs)), 

3. Config files found in the nearest directory hierarchy of the first opened .blend file. 

   For example, before opening `C:\data\projects\ABC\assets\table\table.blend`, `bld` will search for `bld.*` config files from `C:\data\projects\ABC\assets\table` up to `C:\`. If a set of files is found in lower directories (e.g. `C:\data\projects\ABC\bld.yaml`) files further up in the hierarchy (e.g. `C:\data\bld.yaml`) will not be read.

… all accumulated into one internal dictionary with each subsequent files updates the values of prior ones. 

JSON format is primarily for application-generated files (especially `~/bld.json` which is modified each time user registers a new Blender executable), while YAML is chosen to give an optional format that's easier for the user to edit.

## Format

General structure of config file is a dictionary keyed with three section names:

- `paths`: Its value is a dictionary of version spec → Blender executable path. If none of the config files being read have this key, `bld` can't run.
- `switches`: A dictionary of version spec → command line switches.
- `envs`: A dictionary of version spec → dictionary of {environment variable → string or list of strings}.

### Sample:

YAML:

```yaml
paths:
  "2.69": C:\prog\blender-2.69-windows64\blender.exe
  "2.79b": C:\prog\blender-2.79b-windows64\blender.exe
  "4.3.2": C:\prog\blender-4.3.2-windows-x64\blender.exe
  "4.4.0": C:\prog\blender-4.4.0-windows-x64\blender.exe
switches:
  "4": "--background --python-console"
  "4.4": "--version"
envs:
  "4":
    "BLENDER_USER_SCRIPTS": c:\home\blender\v4\scripts
```

JSON:

```json
{
  "paths": {
    "2.69": "C:\\prog\\blender-2.69-windows64\\blender.exe",
    "2.79b": "C:\\prog\\blender-2.79b-windows64\\blender.exe",
    "2.93": "C:\\prog\\blender-2.93.18-windows-x64\\blender.exe",
    "4.3.2": "C:\\prog\\blender-4.3.2-windows-x64\\blender.exe",
  }
}
```

## Version Spec

Version spec is simply a string against which a version string specified by the user will be compared, with the longest match prioritized over shorter ones. For example, with YAML configuration:

```yaml
switches:
  "4": "--background --python-console"
  "4.4": "--version"
```

… `bld` will print Blender version if:

- User specified `-v4.4` as command line argument and it's available in the system,
- User does not specify any version, but v4.4.x is the latest available version.

For any other Blender v4.\*.\* release, either is expressly specified or is the latest available, `bld` will launch its executable with an interactive Python console. 

### Cross-Reference

In `paths` section, a version spec can refer to other version spec, instead of executable path. If a matching spec is found, other sections will be searched in, first based on the literal spec then the matching spec. For example, with this config:

```json
{
  "paths": {
    "4.4.0": "C:\\prog\\blender-4.4.0-windows-x64\\blender.exe",
    "MODELING": "4.4.0"
  },
  "switches": {
    "4.4.0": "--switch4.4.0",
    "MOD": "--switchMOD",
  }
}
```

… running `bld -vM` will run Blender v4.4.0 with `--switchMOD` argument (`MOD` is the longest substring of the literal cross-referencing version spec). Without the `MOD` entry in `switches` dictionary, `bld` will select based on matching spec and use `--switch4.4.0` as command argument.

## Environment Variables

The value of every entries in `envs` dictionary under each version specs can be a string, or a list of strings. This is to accomodate environment variables containing multiple paths joined with platform-specific path separator (e.g. variable `PATH` with value `C:\A;C:\B` adds both directories `C:\A` and `C:\B` into binary search path).

A placeholder for original value of the variable, "`*`", can be added in the list *at most once*, and the variable's original value will be inserted in its place. For example, if variable `PYTHONPATH` has an original value of `C:\A;C:\B`, the configuration:

```yaml
envs:
  "4":
    "PYTHONPATH":
      - D:\E
      - "*"
      - D:\F
```

… will replace the placeholder with that original value, with the resulting value:

```
D:\E;C:\A;C:\B;D:\F
```

With this format, users can determine themselves where in the search order new paths will be added relative to prior one.

### Extra Processing for Blender Scripts Path Variables

If `BLENDER_USER_SCRIPTS` or  `BLENDER_SYSTEM_SCRIPTS` is defined in config `envs`, the path in their values will be checked and created if nonexistent, including its subdirectories `addons` and `startup`. The intent is so the user can just specify a path, then install addons into it immediately after launch.

## Relative Path Substitution

In a config file, a user can specify paths relative to that file with a special notation: Prefix string `\\` will be substituted the config file's path, for these config items:

- Binary paths in `paths` section,
- Individual environment variable value items in `envs` section.

The prefix string can be followed, optionally, with periods ending with another backslash (`..\`) to specify directory levels to go up relative to config file's path.

For example, a config file `C:\data\projects\ABC\bld.yaml` with the following configuration:

```yaml
paths:
	"2.93": "\\..\DEF\blender\blender.exe"
	"5.0.1": "\\blender\blender.exe"
```

… will be processed as:

```yaml
paths:
	"2.93": "C:\data\projects\DEF\blender\blender.exe"
	"5.0.1": "C:\data\projects\ABC\blender\blender.exe"
```



# Version List Update<a id="listupdate"/>

With the amount of version updates, or of custom builds a user may experiment with, manually registering new versions can get unwieldy. `bld` provides an update command that does the following steps:

1. The command `bld --update` collects common parent directories of all executable paths listed. For example, with the following paths listed:

   ```
   "v01": "C:\prog\ver01\blender.exe"
   "v02": "C:\prog\ver02\blender.exe"
   "v03": "C:\prog\blender\stable\ver03\blender.exe"
   ```

   … Their parent directories are `C:\prog` and `C:\prog\blender\stable`.

1. These paths will be read, looking for files named `blender.exe` in all immediate subdirectories.

1. Pruning paths already registered, these files will be invoked with command line switch `--version` to get its version spec string.

1. Per-user `~/bld.json` will be modified, appending these new executables after removing nonexistent paths. New entries keyed with similar version spec string as existing ones will be given numeric suffix `_[index]`.

---
title: bld - Blender Launcher
linkcolor: blue
mainfont: LibertinusSerif
layout: topspace=1cm,height=fit

---
