<div align="center">

# Navita: Navigate Smarter, Not Harder

_Derived from "navigate" and "ita" (short for "iteration"), suggesting a tool that helps you navigate through iterations of directory visits._

[Features](#features) •
[Dependencies](#dependencies) •
[Installation](#installation) •
[Environment Variables](#environment-variables) •
[Concept/Motivation](#conceptmotivation) •
[Contributing to Navita](#contributing-to-navita)

</div>

**Tired of typing out long, complex directory paths?** Navita is here to simplify your command-line experience! The powerful Bash tool uses fuzzy search to get you to your destination in seconds.

**Forget about tedious typing.** You can instantly find and jump to any directory, no matter how deeply nested. Navita is a great tool for boosting your productivity and saving you valuable time.

<div align="center">

## Features

</div>

<div align="center">

### Recursive Directory Search & Traversal

*Feature Name: NavigateChildDirs*

</div>

**Synopsis:** `cd (-s | --sub-search) [<string>...]`

Fuzzy search directories, all its subdirectories, and their subdirectories (so on..), and traverse to the selected one.

<div align="center">

### Parent Directory Search & Traversal

*Feature Name: NavigateParentDirs*

</div>

**Synopsis:** `cd (-S | --super-search) [<string>...]` 

Fuzzy search directories (1-level down) in parent directories and traverse to the selected one.

<div align="center">

### History Search & Traversal

*Feature Name: NavigateHistory*

</div>

**Synopsis:** `cd -- [<string>...]`

Fuzzy search last 50 (default) visited directory paths and traverse to the selected one.

<div align="center">

### View History

*Feature Name: ViewHistory*

</div>

**Synopsis:** `cd (-H | --history)`

View last 50 (default) visited directory paths.

<div align="center">

### Change to Directory

*Feature Name: CDGeneral*

</div>

**Synopsis:** `cd [<string>...]`

Fuzzy search directories in the *current working directory* and traverse to the selected one. If no match is found, Navita would search the history i.e., the same as the *NavigateHistory* feature.

<div align="center">

### Toggle Current & Previous Directories

*Feature Name: ToggleLastVisits*

</div>

**Synopsis:** `cd -`

Switch between the current directory and the previous directory. 

<div align="center">

### Cleanup History

*Feature name: CleanHistory*

</div>

**Synopsis:** `cd (-c | --cleanup)`

This is will give an option to either remove invalid paths from the history or completely empty the history.

<div align="center">

### Version Information

*Feature Name: VersionInfo*

</div>

**Synopsis:** `cd (-v | --version)`

View Navita's version information.

<div align="center">

## Dependencies

</div>

- [FZF](https://junegunn.github.io/fzf/)
- [GNU Sed](https://sed.sourceforge.io/)
- [GNU Gawk](https://www.gnu.org/software/gawk/)
- [GNU Core Utilities](https://www.gnu.org/software/coreutils/)

<div align="center">

## Installation

</div>

1. Download the `navita.sh` file.

```bash
# using wget2
wget2 <raw.githubusercontent.com url to navita.sh...>

# or using curl
curl <raw.githubusercontent.com url to navita.sh...> --output navita.sh
```

2. Source the `navita.sh` file in your .bashrc configuration file.

```bash
source "path/to/the/navita.sh"
```

<div align="center">

## Environment Variables

</div>

> [!NOTE]
> If you want to keep your desired values rather than the default ones, make sure to export these environment variables before sourcing the `navita.sh` file in your `.bashrc`."

- **NAVITA_CONFIG_DIR**
    - Directory location for Navita's configuration files.
    - Defaults to `$XDG_CONFIG_HOME/navita`
    - If `XDG_CONFIG_HOME` is not set, it defaults to `~/.config/navita`.

- **NAVITA_HISTORYFILE**
    - Absolute path of the history file, which contains last 50 (default) visited paths.
    - Defaults to `$NAVITA_CONFIG_DIR/navita-history`.

- **NAVITA_HISTORYFILE_SIZE**
    - Number of last visited directory paths Navita should track.
    - Defaults to `50`.

- **NAVITA_COMMAND**
    - Name of the command to use Navita.
    - Defaults to `cd`.

- **NAVITA_FOLLOW_ACTUAL_PATH**
    - Follow symbolic links and resolve them to their actual physical locations before making the directory change.
    - Defaults to `n`, i.e., not to follow symbolic links.
    - Change it to `y` or `Y` to follow symbolic links.

<div align="center">

## Concept/Motivation

</div>

- To address the tedium of the builtin `cd` command.
- KISS&E - Keep It Simple, Straightforward & Efficient.
- No feature bloating.

<div align="center">

## Contributing to Navita

### Reporting Issues

</div>

If you encounter any bugs or issues while using Navita, please open an issue on the Navita GitHub repository. Provide as much detail as possible, including steps to reproduce the issue and any relevant error messages.

<div align="center">

### Contributing Code

</div>

I welcome contributions from the community! If you'd like to contribute, please:

- Fork the repository.
- Make your changes and submit a pull request to the **dev** branch. 

> [!NOTE]
> Please do not submit pull requests to the main branch.

I will review your pull request and provide feedback. Once your contribution is approved, it will be merged into the main repository.

