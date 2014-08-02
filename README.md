Dominus
=======

Dominus is a world class command line tool to improve workflow with developing iOS projects. It allows completely automated deployment from console and/or [Travis CI](https://travis-ci.com), which can be triggered remotely.

# Features

- Loading new devices from TestFlight to Apple Developer Portal
- Updating provisioning profiles
- Building and testing application with automatic scheme detection
- Deployment to TestFlight

In addition to features available on Travis CI, Dominus can also help with:

- Project creation
- Quality control

# Installation

The easiest way to add Dominus to a project just add a Git submodule. Make sure you update it before launching. Dominus has an automatic updating mechanism, that will always bring the script up to date.

# Configuration file

The file dominus.cfg is so called configuration file, it stores all project related information locally.

**Make sure to add configuration file to .gitignore, so it is not commited to the repository as it can contain sensitive data.** On Travis always use encrypted environment variables (can be done with travis encrypt command) instead.

# Usage

To see all commands available, just run the help command:

`dominus.sh help`

# Structure

Dominus is separated into three modules, which are composited mostly from Bash scripts.

- Setup - Takes care of setuping variables and files to work correctly with Dominus.
- Deploy - Takes care of deploying a project to distribution service.
- Notifications - Sending notifications to a chat room or application during deployment.

# Travis CI

To integrate with Travis CI run the next command:

`dominus.sh setup travis`

This command will generate `.travis.yml` file which is then easily commited to your repository. Enter the variables, which are then encrypted using Travis CI private keys.

# TODO

- Automatically updating Dominus submodule with latest version
- Loading Git history when deploying and adding it to message
- Configuration for different branches for testing and deploying

Contact
======

Dal Rupnik

- [legoless](https://github.com/legoless) on **GitHub**
- [@thelegoless](https://twitter.com/thelegoless) on **Twitter**
- [legoless@arvystate.net](mailto:legoless@arvystate.net)

License
======

Dominus is available under the MIT license. See [LICENSE](https://github.com/Legoless/Dominus/blob/master/LICENSE) file for more information.
