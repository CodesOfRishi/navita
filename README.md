<div align="center">

# Navita: Navigate Smarter, Not Harder

_Derived from "navigate" and "ita" (short for "iteration"), suggesting a tool that helps you navigate through iterations of directory visits._

[Features](#features) •
[Dependencies](#dependencies) •
[Installation](#installation) •
[Environment Variables](#environment-variables) •
[Concept/Motivation](#conceptmotivation) •
[Contributing to Navita](#contributing-to-navita) •
[LICENSE](#license)

</div>

**Tired of typing out long, complex directory paths?** Navita is here to simplify your command-line experience! The powerful Bash tool uses fuzzy search to get you to your destination in seconds.

**Forget about tedious typing.** You can instantly find and jump to any directory, no matter how deeply nested. Navita is a great tool for boosting your productivity and saving you valuable time.

<div align="center">

## Features

</div>

<div align="center">

### Search & Traverse Child Directories

*Feature Name: NavigateChildDirs*

</div>

**Synopsis:** `cd (-s | --sub-search) [string...]`

Search subdirectories, and their subdirectories (and so on), and navigate to the selected one.



<div align="center">

### Search & Traverse Parent Directories

*Feature Name: NavigateParentDirs*

</div>

**Synopsis:** `cd (-S | --super-search | ..) [string...]` 

Search directories (1-level down) in parent directories and navigate to the selected one.

<div align="center">

### Search & Traverse History

*Feature Name: NavigateHistory*

</div>

**Synopsis:** `cd -- [string...]`

Search recently visited directory paths and navigate to the selected one. This feature can still be used by omitting the -- option if the provided string does not match any directory paths in your PWD. See the [*CDGeneral*](#change-to-directory) feature.

> [!NOTE]
> Visit a few directories after a clean or initial installation to build a history.

<div align="center">

### View History

*Feature Name: ViewHistory*

</div>

**Synopsis:** `cd (-H | --history) [string...]`

View recently visited directory paths.

<div align="center">

### Change to Directory

*Feature Name: CDGeneral*

</div>

**Synopsis:** `cd [string...]`

Search directories in the *current working directory* and navigate to the selected one. If no match is found, Navita would search the history i.e., the same as the [*NavigateHistory*](#search--traverse-history) feature.

<div align="center">

### Toggle Current & Previous Directories

*Feature Name: ToggleLastVisits*

</div>

**Synopsis:** `cd -`

Switch between your current directory and the previous directory you were in.

> [!NOTE]
> `cd -` only works if you've used `cd` to change directories previously. If you haven't used `cd` before in the current shell, `cd -` won't do anything.

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

### Tab Completion

*Feature Name: TabCompletion*

</div>

- Navita supports Tab completion for its options and directories in your PWD.

<div align="center">

### Aging

*Feature Name: AgeOutHistory*

</div>

- By default, Navita will remember directories for a maximum of 30 days. Any directories that have not been accessed in over 30 days will be forgotten. This value can be changed using the `NAVITA_MAX_AGE` environment variable.

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

### Addional Info

</div>

- Navita will prioritize search results based on the position of the match within the directory path, giving preference to matches near the end and then considering the recency of the path.
- Navita has a few default annotations that are visible when using the [ViewHistory](view-history) or [NavigateHistory](search--traverse-History) feature. These include error, PWD, and LWD (last working directory) annotations.



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
> If you want to keep your desired values rather than the default ones, make sure to export these environment variables *before* sourcing the `navita.sh` file in your `.bashrc`.

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

- **NAVITA_AUTOMATIC_EXPIRE_PATHS**
    - It defaults to `y` i.e., check for outdated directory paths in the history at every shell startup.
    - Change it to `n` or `N` to prevent Navita from checking for outdated directory paths.

- **NAVITA_DATA_DIR**
    - Directory location for Navita's data files.
    - Defaults to `$XDG_DATA_HOME/navita`
    - If `XDG_DATA_HOME` is not set, it defaults to `~/.local/share/navita`.

- **NAVITA_CONFIG_DIR**
    - Directory location for Navita's configuration files.
    - Defaults to `$XDG_CONFIG_HOME/navita`
    - If `XDG_CONFIG_HOME`  is not set, it defaults, `~/.config/navita`.

- **NAVITA_VERSION**
    - Show the Navita version information.

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
