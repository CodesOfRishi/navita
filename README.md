<div align="center">

# Navita: Navigate Smarter, Not Harder

_Derived from "navigate" and "ita" (short for "iteration"), suggesting a tool that helps you navigate through iterations of directory visits._

[Features](#features) •
[Dependencies](#dependencies) •
[Installation](#installation) •
[Environment Variables](#environment-variables) •
[Concept/Motivation](#conceptmotivation) •
[Contributing to Navita](#contributing-to-navita) •
[License](#license)

</div>

**Tired of typing out long, complex directory paths?** Navita is here to simplify your command-line experience! The powerful Bash tool uses fuzzy search to get you to your destination in seconds.

**Forget about tedious typing.** You can instantly find and jump to any directory, no matter how deeply nested. Navita is a great tool for boosting your productivity and saving you valuable time.

<div align="center">

## Features

</div>

<div align="center">

### Usual Directory Change

</div>

**Synopsis:** `cd [string...]`

Search directories in the *current working directory* and navigate to the selected one. If no match is found, Navita will search the history and directly navigate to the matching highest-ranked directory.

<div align="center">

### Search & Traverse Child Directories

</div>

**Synopsis:** `cd (-s | --sub-search) [string...]`

Search subdirectories, and their subdirectories (and so on), and navigate to the selected one.



<div align="center">

### Search & Traverse Parent Directories

</div>

**Synopsis:** `cd (-S | --super-search) [string...]`<br>
&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;`cd .. string...`

Search directories (1-level down) in parent directories and navigate to the selected one.

<div align="center">

### Search & Traverse History

</div>

**Synopsis:** `cd -- [string...]`

Search recently visited directory paths and navigate to the selected one. This feature can still be used by omitting the `--` option if the provided string does not match any directory paths in your PWD. See the [*Usual Directory Change*](#usual-directory-change) feature.

> [!NOTE]
> Visit a few directories after a clean or initial installation to build a history.

<div align="center">

### View History

</div>

**Synopsis:** `cd (-H | --history) [string...]`

View recently visited directory paths.

<div align="center">

### Toggle Current & Previous Directories

</div>

**Synopsis:** `cd -`

Switch between your current directory and the previous directory you were in.

> [!NOTE]
> `cd -` only works if you've used `cd` to change directories previously. If you haven't used `cd` before in the current shell, `cd -` won't do anything.

<div align="center">

### Clean-up History

</div>

**Synopsis:** `cd (-c | --cleanup)`

You can choose to either remove invalid paths from the history or clear the entire history.

<div align="center">

### Version Information

</div>

**Synopsis:** `cd (-v | --version)`

View Navita's version information.

<div align="center">

### Tab Completion

</div>

Navita supports Tab completion for its options and directories in your PWD.

<div align="center">

### Path Exclusion for History

</div>

- Prevent paths that match any regular expression pattern in the `$NAVITA_IGNOREFILE` file from being added to the history.
- Navita does not add the .git directory to the history by default.

> [!NOTE]
> Even if a path was part of the history prior to its inclusion in the `$NAVITA_IGNOREFILE` using a regular expression pattern, it will still be visible, but Navita will cease to boost its ranking.

<div align="center">

### Aging

</div>

By default, Navita will remember directories for a maximum of 30 days. Any directories that have not been accessed in over 30 days will be forgotten. This value can be changed using the `NAVITA_MAX_AGE` environment variable.

> [!NOTE]
> For Navita, age is relative to the most recently accessed directory.
> For example, if the most recently accessed directory was accessed at time `a` and another directory was accessed at time `(a+x)`, then the age of the other directory is `x` time units.

<!--<div align="center">-->
<!---->
<!--### Add Annotations-->
<!---->
<!--*Feature Name: UserAnnotations*-->
<!---->
<!--</div>-->
<!---->
<!--- Annotate a specific directory path with a note or comment that will appear in the [ViewHistory](view-history) or [NavigateHistory](search--traverse-History) feature.-->

<div align="center">

### Additional Info

</div>

- For Navita to follow physical directory structures, use the `-P` option along with the other options. This will resolve symbolic links and navigate you to the actual physical location on disk.
    - To make Navita *always* resolve symbolic links, check the `NAVITA_FOLLOW_ACTUAL_PATH` environment variable.

> [!NOTE]
> If this option is used, it should be the very first option given to Navita.

- Navita will prioritize search results based on the position of the match within the directory path, giving preference to matches near the end and then considering the recency of the path.
<!--- Navita has a few default annotations that are visible when using the [ViewHistory](view-history) or [NavigateHistory](search--traverse-History) feature. These include error, PWD, and LWD (last working directory) annotations.-->

<div align="center">

## Dependencies

</div>

- [FZF](https://junegunn.github.io/fzf/)
- [GNU Sed](https://sed.sourceforge.io/)
- [GNU Grep](https://www.gnu.org/software/grep/)
- [GNU bc](https://www.gnu.org/software/bc/)
- [GNU Find Utilities](https://www.gnu.org/software/findutils/) (basically the `find` command)
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
> If you want to keep your desired values rather than the default ones, make sure to export these environment variables *before* sourcing the `navita.sh` file in your `.bashrc`.

- **NAVITA_DATA_DIR**
    - Directory location for Navita's data files.
    - Defaults to `$XDG_DATA_HOME/navita`
    - If `XDG_DATA_HOME` is not set, it defaults to `~/.local/share/navita`.

- **NAVITA_CONFIG_DIR**
    - Directory location for Navita's configuration files.
    - Defaults to `$XDG_CONFIG_HOME/navita`
    - If `XDG_CONFIG_HOME`  is not set, it defaults to `~/.config/navita`.

- **NAVITA_COMMAND**
    - Name of the command to use Navita.
    - Defaults to `cd`.

- **NAVITA_FOLLOW_ACTUAL_PATH**
    - Follow symbolic links and resolve them to their actual physical locations before making the directory change.
    - Defaults to `n`, i.e., not to follow symbolic links.
    - Change it to `y` or `Y` to follow symbolic links.

- **NAVITA_MAX_AGE**
    - Specifies maximum retention period for a directory path since last access.
    - The default value is `30` i.e., 30 days.

- **NAVITA_RELATIVE_PARENT_PATH**
    - It defaults to `y` i.e., show the resolved parent paths relative to PWD in *Search & Traverse Parent Directories* feature.
    - Change it to `n` or `N` to show the parent paths as absolute path. 

- **NAVITA_IGNOREFILE**
    - The file containing regular expression patterns to ignore matching paths from being added to the history.
    - The path to the file is `$NAVITA_CONFIG_DIR/navita-ignore`.
- **NAVITA_SHOW_AGE**
    - It defaults to `n`, i.e., don't show an age annotation next to the paths while searching and traversing from history.
    - Change it to `y` or `Y`, to show an age annotation beside the paths.

- **NAVITA_VERSION**
    - Navita's version information.

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

> [!WARNING]
> Please do not submit pull requests to the main branch.

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) for details.
