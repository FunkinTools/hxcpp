# hxcpp — FunkinTools Fork

> A focused fork of [hxcpp](https://github.com/HaxeFoundation/hxcpp) built for Friday Night Funkin' engines.

[![Build Status](https://dev.azure.com/HaxeFoundation/GitHubPublic/_apis/build/status/HaxeFoundation.hxcpp?branchName=master)](https://dev.azure.com/HaxeFoundation/GitHubPublic/_build/latest?definitionId=3&branchName=master)

---

## What is hxcpp?

hxcpp is the runtime support for the C++ backend of the [Haxe](https://haxe.org/) compiler.
It provides the headers, libraries, and support code required to compile Haxe code into a fully native executable.

This fork extends the upstream with improvements targeting Friday Night Funkin' engine development,
including better Android/iOS toolchain support, NDK compatibility fixes, and build pipeline enhancements.

---

## Requirements

- [Haxe](https://haxe.org/download/) 4.3.0 or later
- [Neko](https://nekovm.org/download/) 2.3.0 or later
- For Android builds: NDK r25c, Java 17

---

## Installation

### Via haxelib (recommended)

```bash
haxelib git hxcpp https://github.com/FunkinTools/hxcpp
```

### Local development

```bash
git clone https://github.com/FunkinTools/hxcpp
haxelib dev hxcpp /path/to/hxcpp
```

---

## Building the Tools

```bash
REPO=$(pwd)

cd ${REPO}/tools/run
haxe compile.hxml

cd ${REPO}/tools/hxcpp
haxe compile.hxml

cd $REPO
```

---

## cppia

Build the cppia host first:

```bash
REPO=$(pwd)
cd ${REPO}/project
haxe compile-cppia.hxml
cd $REPO
```

Then run any `.cppia` script with:

```bash
haxelib run hxcpp file.cppia
```

---

## Project Structure

| Directory     | Description                                     |
|---------------|-------------------------------------------------|
| `src/`        | C++ runtime source (GC, threads, strings, etc.) |
| `include/`    | Public C++ headers                              |
| `toolchain/`  | Platform-specific toolchain configs             |
| `tools/`      | Haxe build orchestration tools                  |
| `project/`    | Native binary build scripts                     |
| `build-tool/` | Core build tool source                          |

---

## License

BSD — see [LICENSE.txt](LICENSE.txt).

Upstream: [HaxeFoundation/hxcpp](https://github.com/HaxeFoundation/hxcpp)
