# Newt, the project scaffolder for Janet

## Setup and Example

First, have [janet installed](https://github.com/janet-lang/janet/releases), and up things so that jpm installed programs end up on your $PATH

```
git clone https://github.com/yumaikas/newt`
jpm install
```

Navigate to an emtpy dir

```
newt -n my-project -a "Andrew Owen" -l mit
```

This will create a `README.md`, `LICENSE.md`, `my-project.janet`, and a test folder and a `project.janet`.

## Usage

Newt expects an author, a project name, and a license. Each one can be set using either a command-line flag, or an environment variable. In addtion, author may try to pull your author information from git.


## Status

0.1 Feel free to read the code or try it out, but still in flux

