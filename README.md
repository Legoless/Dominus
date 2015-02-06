Dominus
=======

Dominus is a world class command line tool to improve workflow with developing iOS projects. It allows completely automated deployment from console and/or [Travis CI](https://travis-ci.com), which can be triggered remotely by specific build branches. Dominus also helps with increasing the quality of your projects, by integrating different tools into one larger development tool.

# Features

- Building iOS Projects
  - Multiple targets or schemes
  - Different SDK's
  - Automatic build process
- Testing iOS Projects
  - Using different iOS Simulators or real devices
  - Test report coverage
  - Automatic test process
- Updating Provisioning Profiles
  - Loading new devices from TestFlight to Apple Developer Portal
  - Regenerating provisioning profiles on demand
- Quality control
  - Code static analysis with [Faux Pas](http://fauxpasapp.com/)
- Deployment to TestFlight, Crashlytics
  - Automatic build project increase (on Travis CI only)
  - Release notes from Git history (on Travis CI only)
  - Configure which branches should deploy
- Detailed notification system (HipChat)
- Travis CI Full Support, including project configuration
- Dashboard Reporting Panel and Ad-Hoc distribution

# Installation

The easiest way to add Dominus to a project just add a Git submodule. Make sure you update it before launching. Dominus has an automatic updating mechanism, that will always bring the script up to date.

# Configuration file

The file `dominus.cfg` is so called configuration file, it stores all project related information locally and allows the replication of CI environment.

**Make sure to add configuration file to .gitignore, so it is not commited to the repository as it can contain sensitive data.** On Travis always use encrypted environment variables (can be done with travis encrypt command) instead.

# Usage

To see all commands available, just run the help command:

`dominus.sh help`

# Architecture

Dominus is separated into three modules, which are composited mostly from Bash scripts.

- Setup - Takes care of setuping variables and files to work correctly with Dominus.
- Deploy - Takes care of deploying a project to distribution service.
- Notifications - Sending notifications to a chat room or application during deployment.

# Travis CI

To integrate with Travis CI run the next command:

`dominus.sh setup travis`

This command will generate `.travis.yml` file which is then easily commited to your repository. Enter the variables, which are then encrypted using Travis CI private keys. It will also configure running of Dominus according to your input. If there is a `dominus.cfg` present in the same directory, it will generate `.travis.yml` from the configuration file present.

# TODO

- Code formatting checker (Obj-Clean or some code formatter)
- Push notification support (Shenzhen)
- Code coverage generation and upload
- Action mapping per branch (using Thalion gem)
- Apple TestFlight support
- HockeyApp support
- Xcode archive support
- Build unsigned .IPA
- Documentation & Wiki

Contact
======

Dal Rupnik

- [legoless](https://github.com/legoless) on **GitHub**
- [@thelegoless](https://twitter.com/thelegoless) on **Twitter**
- [legoless@arvystate.net](mailto:legoless@arvystate.net)

License
======

Dominus is available under the MIT license. See [LICENSE](https://github.com/Legoless/Dominus/blob/master/LICENSE) file for more information.
