Dominus
=======

Dominus is a world class command line tool to improve workflow with iOS projects. It allows completely automated deployment and is fully integrated with [Travis CI](https://travis-ci.com). 

# Features

- Deployment to TestFlight
- Project creation

# Installation

To add Dominus to a project just add a Git submodule.

# Configuration file

**Make sure to add configuration file to .gitignore, so it is not commited to the repository as it can contain sensitive data.**

# Travis CI

To integrate run the next command:

`dominus.sh setup travis`

This command will generate `.travis.yml` file which is then easily commited to your repository.
