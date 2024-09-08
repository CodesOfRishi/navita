<div align="center">

# Navita: Navigate Smarter, Not Harder

_Derived from "navigate" and "ita" (short for "iteration"), suggesting a tool that helps you navigate through iterations of directory visits._

[Features](#features) •
[Dependencies](#dependencies) •
[Installation](#installation) •
[Environment Variables](#environment-variables) •
[Known Caveats](#known-caveats) •
[Concept/Motivation](#conceptmotivation) •
[Contributing to Navita](#contributing-to-navita) •
[License](#license)


**Tired of typing out long, complex directory paths?** Navita is here to simplify your command-line experience! The powerful Bash tool uses fuzzy search to get you to your destination in seconds.

**Forget about tedious typing.** You can instantly find and jump to any directory, no matter how deeply nested. Navita is a great tool for boosting your productivity and saving you valuable time.

</div>

> [!IMPORTANT]
> Navita is currently under development.

<div align="center"> 

## Features 

</div>

<div align="center"> 

### Usual Directory Change

</div>

**Synopsis:** `cd [string...]`

- Navita will search the history and directly navigate to the highest-ranked matching directory. The current working directory will not be considered in the search.
- You can also navigate directories the same way you would with the usual built-in cd command.

> [!NOTE]
> Navita will compare the last word of the string argument to the end of the paths in the history to determine the highest-ranked matching directory.<br> 

<div align="center"> 

### Search & Traverse Child Directories

</div>

**Synopsis:** `cd (-s | --sub-search) [string...]`

Recursively search subdirectories, excluding .git and its subdirectories, and navigate to the selected one.

<div align="center"> 

### Search & Traverse Parent Directories

</div>


**Synopsis:** `cd (-S | --super-search) [string...]`<br>
&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;`cd .. string...`

Search directories one level below the parent directories and navigate to the desired one. The current working directory will not be considered in the search.

<div align="center"> 

### Search & Traverse History

</div>

**Synopsis:** `cd -- [string...]`

Search your recently visited directories and select the desired one. The current working directory will not be considered in the search.

> [!NOTE]
> Visit a few directories after a clean or initial installation to build a history.

<div align="center"> 

### View History

</div>

**Synopsis:** `cd (-H | --history [--by-time | --by-frequency | --by-score])`

- See Navita's history of visited directories. 
- The history will be displayed in the `less` pager, or directly to STDOUT if it fits on a single screen. The output will be sorted based on the provided option:
    - `--by-time`: Sorts the history by access time, with the most recently accessed directories appearing first.
    - `--by-freq`: Sorts the history by frequency, showing the most frequently accessed directories first.
    - `--by-score`: Sorts the history by score, with the highest scoring directories at the top. This is the default option.

<div align="center"> 

### Toggle Current & Previous Directories

</div>

**Synopsis:** `cd -`

Switch between your current directory and the previous directory you were in. The previous directory is specific to the current shell.

<div align="center"> 

### Clean-up History

</div>

**Synopsis:** `cd (-c | --cleanup)`

You can choose to either remove invalid paths from the history or clear the entire history. However, Navita will automatically remove non-existent and non-executable directories.

<div align="center"> 

### Version Information

</div>

**Synopsis:** `cd (-v | --version)`

View Navita's version information.

<div align="center"> 

### Tab Completion

</div>

Navita supports Tab completion for its options (in only Bash as of now) and directories.

<div align="center"> 

### Path Exclusion for History

</div>

- Prevent paths that match any regular expression pattern in the `$NAVITA_IGNOREFILE` file from being added to the history.
- Navita automatically prevents the `.git` and `$HOME` directories from being added to the history by default.

> [!NOTE]
> Even if a path was part of the history prior to its inclusion in the `$NAVITA_IGNOREFILE` using a regular expression pattern, it will still be visible, but Navita will cease to boost its ranking.

<div align="center"> 

### Frecency Directory Ranking

</div>

The Frecency algorithm ranks directories based on a combination of two factors: 
- frequency (how often a directory is accessed) and, 
- recency (how recently it was accessed). 

This ensures that the most relevant directories—those accessed both frequently and recently—are ranked higher, while directories with older access are deprioritized. 

<details>
<summary>How it Works?</summary> 

$$
\text{Score} = \ln(\frac{F \times (T_2-T_1)}{T_2}+1) \times e^{(-k \times (T_1/T_2))}
$$

where:
- F is the frequency of access.
- T1 is the time difference between the most recent access and the current directory.
- T2 is the maximum time difference allowed (90 days).
- k controls the rate at which the weight of older accesses decreases. A higher value results in a faster decay rate. Check [`NAVITA_DECAY_FACTOR`](#environment-variables) environment variable.
- The logarithmic scaling reduces the impact of extremely high frequencies, ensuring a more balanced ranking.
- The exponential decay gradually reduces the importance of older accesses, prioritizing recent activity.

</details>

<div align="center"> 

### Aging

</div>

- By default, Navita will remember directories for a maximum of 90 days. Any directories that have not been accessed in over 90 days will be forgotten. This value can be changed using the [`NAVITA_MAX_AGE`](#environment-variables) environment variable.
- For Navita, age is relative to the most recently accessed directory. For example, if the most recently accessed directory was accessed at time `a` and another directory was accessed at time `(a+x)`, then the age of the other directory is `x` time units.

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

- For Navita to follow physical directory structures, use the `-P` option along with the other options. This will resolve symbolic links and navigate you to the actual physical location on disk. To make Navita *always* resolve symbolic links, check the [`NAVITA_FOLLOW_ACTUAL_PATH`](#environment-variables) environment variable.

> [!NOTE]
> If this option is used, it should be the very first option given to Navita.

- Search syntax is same as the [FZF search syntax](https://junegunn.github.io/fzf/search-syntax/).

<div align="center"> 

## Dependencies

</div>

- [GNU Bash](http://tiswww.case.edu/php/chet/bash/bashtop.html) (or [Zsh](https://www.zsh.org/) likely in the future)
- [FZF](https://junegunn.github.io/fzf/)
- [GNU Grep](https://www.gnu.org/software/grep/)
- [GNU bc](https://www.gnu.org/software/bc/)
- [GNU Find Utilities](https://www.gnu.org/software/findutils/) (basically the `find` command)
- [GNU Core Utilities](https://www.gnu.org/software/coreutils/)
- [Less](http://www.greenwoodsoftware.com/less/) (only for viewing the history in a pager)

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
    - The default value is `90` i.e., 90 days.

- **NAVITA_RELATIVE_PARENT_PATH**
    - It defaults to `y` i.e., show the resolved parent paths relative to the present working directory in *Search & Traverse Parent Directories* feature.
    - Change it to `n` or `N` to show the parent paths as absolute path. 

- **NAVITA_IGNOREFILE**
    - The file containing regular expression patterns to ignore matching paths from being added to the history.
    - The path to the file is `$NAVITA_CONFIG_DIR/navita-ignore`.
- **NAVITA_SHOW_AGE**
    - It defaults to `y`, i.e., show an age annotation next to the paths while searching and traversing from history.
    - Change it to `y` or `Y`, to not show an age annotation beside the paths.
- **NAVITA_DECAY_FACTOR**
    - The rate at which the score of older accesses decreases. A higher value results in a faster decay rate.
    - It defaults to `6`.

> [!WARNING]
> The decay factor should always be positive. Only adjust the decay factor if you are confident in the algorithm's behavior with the new value.

- **NAVITA_VERSION**
    - Navita's version information.

<div align="center"> 

## Known Caveats

</div>

- [FZF Issue #3983](https://github.com/junegunn/fzf/issues/3983)

<div align="center"> 

## Concept/Motivation

</div>

- To address the tedium of the builtin `cd` command.
- KISS&E - Keep It Simple, Straightforward & Efficient.
- No feature bloating.

<div align="center"> 

## Contributing to Navita

</div>

<div align="center"> 

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

<div align="center"> 

## License

</div>

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) for details.
