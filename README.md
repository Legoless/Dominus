Dominus
=======

Dominus is an easy to use bootstrap command line tool for Continuous Integration. It allows completely automated deployment from console and/or [Travis CI](https://travis-ci.com), which can be triggered remotely by specific build branches. Dominus also helps with increasing the quality of your projects, by integrating different tools into one streamlined development workflow.

In many ways it is similar to [**FastLane**](https://github.com/KrauseFx/fastlane), but it has less features and it is easier to integrate. In fact is uses Fastlane under the hood to keep compatible.

**Dominus has only one specific goal: Easy integration.** As much information as possible should be read from project file instead of asking developer to set things in configuration file. Dominus generates a basic Fastlane file and runs fastlane with prepared configuration.

# Features

- Building iOS projects using Fastlane (gym)
- Testing iOS project using Fastlane (scan)

# Installation

The easiest way to add Dominus to a project just add a Git submodule. Make sure you update it before launching. When integration command is ran, it will automatically update the submodule (if present).

```
git submodule add https://github.com/Legoless/Dominus.git
```

Alternatively you can run Dominus directly with:

```
curl -fsSL https://raw.githubusercontent.com/legoless/Dominus/master/install.sh | sh
```

This script will install and run Dominus script and can be used on Continuous Integration servers without any submodules or repository changes.

# Configuration

Dominus is configured with several environment variables which:
- Can be specified in configuration file `dominus.cfg`, which stores all project related information locally and allows the replication of CI environment.
- Set by server or bash

**Make sure to add configuration file to .gitignore, so it is not commited to the repository as it can contain sensitive data.** On Travis always use encrypted environment variables (can be done with travis encrypt command) instead.

# Usage

To run Dominus just start it with:

`dominus.sh integrate`

And Dominus will do the rest.

# Architecture

Dominus is separated into three modules, which are composited mostly from Bash scripts.

- Setup - Takes care of setuping variables and files to work correctly with Dominus.
- Deploy - Takes care of deploying a project to distribution service.
- Notifications - Sending notifications to a chat room or application during deployment.

# Travis CI

To integrate with Travis CI run the next command:

`dominus.sh setup travis`

This command will generate `.travis.yml` file which is then easily commited to your repository. Enter the variables, which are then encrypted using Travis CI private keys. It will also configure running of Dominus according to your input. If there is a `dominus.cfg` present in the same directory, it will generate `.travis.yml` from the configuration file present.

## Sample .travis.yml

### Using a submodule:

```
language: objective-c
sudo: false
before_install:
- chmod +x ./Dominus/dominus.sh
- "./Dominus/dominus.sh update"
script:
- "./Dominus/dominus.sh integrate"
env:
  matrix:
  - ACTION=build
  - ACTION=test
  global:
  - SDK=8.1
  - PLATFORM='iphone'
```

### Using the install script:

```
language: objective-c
sudo: false
script:
- curl -fsSL https://raw.githubusercontent.com/legoless/Dominus/master/install.sh | sh
env:
  matrix:
  - ACTION=build
  - ACTION=test
  global:
  - SDK=8.1
  - PLATFORM='iphone'
```

# TODO

- Code formatting checker (Obj-Clean or some code formatter)
- Push notification support (Shenzhen)
- Action mapping per branch (using Thalion gem)
- Build unsigned .IPA (without certificate)
- Documentation & Wiki
- Custom shell script support

Contact
======

Dal Rupnik

- [legoless](https://github.com/legoless) on **GitHub**
- [@thelegoless](https://twitter.com/thelegoless) on **Twitter**
- [legoless@arvystate.net](mailto:legoless@arvystate.net)

License
======

**Dominus** is available under the MIT license. See [LICENSE](https://github.com/Legoless/Dominus/blob/master/LICENSE) file for more information.
