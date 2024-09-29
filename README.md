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

![navita-demo](https://github.com/user-attachments/assets/ed52b857-85cb-42f3-95f0-9de22240863b)

</div>

<div align="center"> 

## Features 

</div>

<div align="center"> 

### Usual Directory Change

</div>

**Synopsis:** `cd [string...]`

- Navita will search the history and directly navigate to the highest-ranked matching directory. The current working directory will not be considered in the search.
- For highest-ranked directory traversal, search strings will be matched using [Perl-compatible regular expressions (PCREs)](https://en.wikipedia.org/wiki/Perl_Compatible_Regular_Expressions) and are compared case-sensitively.
- Navita has two exceptions when using PCREs, mainly to keep things (almost) compatible with FZF search syntax.
    - The `.` character will be treated literally.
    - The `!` character can be used to exclude matches for a specified search pattern or word.

    ```bash
    # For example, navigate to the highest-ranked directory path 
    # that does not contain the substring 'smartcd' 
    # and ends with the substring '.config'.
    cd \!smartcd .config
    # OR
    cd '!smartcd' .config
    ```

> [!NOTE]
> Navita will compare the last word of the string argument to the end of the paths in the history to determine the highest-ranked matching directory.
> You can override this behaviour by explicitly specifying `$` (End-of-String Anchor) in your search string.<br> 

<details>
<summary>
<b>Useful PCRE search syntaxes↴</b>
</summary><br>

| Pattern               | Info                                     |
| --------------------- | ---------------------------------------- |
| `a`                   | The character `a`                        |
| `ab`                  | The string `ab`                          |
| <code>a&#124;b</code> | `a` or `b`                               | 
| `a*`                  | 0 or more `a`'s                          |
| `\`                   | Escapes a special character              |
| `*`                   | 0 or more                                |
| `+`                   | 1 or more                                |
| `?`                   | 0 or 1                                   |
| `{2}`                 | Exactly 2                                |
| `{2,5}`               | Between 2 and 5                          |
| `{2,}`                | 2 or more                                |
| `[ab-d]`              | One character of: `a`, `b`, `c`, `d`     |
| `[^ab-d]`             | One character except: `a`, `b`, `c`, `d` |
| `\d`                  | One digit                                |
| `\D`                  | One non-digit                            |
| `\s`                  | One whitespace                           |
| `\S`                  | One non-whitespace                       |
| `\w`                  | One word character                       |
| `\W`                  | One non-word character                   |
| `^`                   | Start of string                          |
| `$`                   | End of string                            |
| `\b`                  | Word boundary                            |
| `\B`                  | Non-word boundary                        |
| `[:alnum:]`           | Letters and digits                       |
| `[:alpha:]`           | Letters                                  |
| `[:digit:]`           | Decimal digits                           |
| `[:ascii:]`           | Ascii codes 0 - 127                      |
| `[:blank:]`           | Space or tab only                        |
| `[:space:]`           | Whitespace                               |
| `[:lower:]`           | Lowercase letters                        |
| `[:upper:]`           | Uppercase letters                        |
| `[:word:]`            | Word characters                          |

</details>

- You can also navigate directories the same way you would with the usual built-in cd command.

<div align="center"> 

### Search & Traverse Child Directories

</div>

**Synopsis:** `cd (-s | --sub-search) [string...]`

Recursively search subdirectories, excluding `.git` and its subdirectories, and navigate to the selected one.

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

**Synopsis:** `cd (-H | --history) [--by-time | --by-frequency | --by-score]`

View Navita's history of visited directories. The history will be displayed in the `less` pager, or directly to STDOUT if it fits on a single screen. The output will be sorted based on the provided option:
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

**Synopsis:** `cd (-c | --clean) [--invalid-paths | --full-history]`

You can choose to either remove invalid paths from the history or clear the entire history. However, Navita will automatically remove non-existent and non-executable directories.

<div align="center"> 

### Version Information

</div>

**Synopsis:** `cd (-v | --version)`

View Navita's version information.

<div align="center"> 

### Tab Completion

</div>

- Navita supports Tab completion for its options and directories.
- For Zsh, to initialize the completion system, the function `compinit` should be autoloaded, and then run simply as ‘`compinit`’. *Ref: [Zsh Completion System - Use of Compinit](https://zsh.sourceforge.io/Doc/Release/Completion-System.html#Use-of-compinit)*

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

$$ \text{Score} = \ln\left(\frac{F \times (T_2-T_1)}{T_2}+1\right) \times e^{\left(\frac{-k \times T_1}{T_2}\right)} $$

where:
- `F` is the frequency of access.
- `T1` is the time difference between the most recent access and the current directory.
- `T2` is the maximum time difference allowed (90 days default). Check [`NAVITA_MAX_AGE`](#environment-variables) environment variable.
- `k` controls the rate at which the weight of older accesses decreases. Check [`NAVITA_DECAY_FACTOR`](#environment-variables) environment variable.
- The logarithmic scaling reduces the impact of extremely high frequencies, ensuring a more balanced ranking.
- The exponential decay gradually reduces the importance of older accesses, prioritizing recent activity.

</details>

<div align="center"> 

### Aging

</div>

- Directory paths are forgotten based on the following two conditions:
    1. Limit the maximum number of entries in the `$NAVITA_HISTORYFILE` file to 5000.
    2. If a directory path's score falls to 0, an average score will be calculated. Directory paths with scores less than 20% of the average score will be removed. 
- These conditions will be checked once every 24 hours at shell startup.
- If a directory path is removed due to a score of 0, the remaining directory paths will have their frequencies adjusted according to the formula $\ln(F+1)$, where $F$ is the frequency of the particular directory path.

<div align="center"> 

### Additional Info

</div>

- For Navita to follow physical directory structures, use the `-P` option along with the other options. This will resolve symbolic links and navigate you to the actual physical location on disk. To make Navita *always* resolve symbolic links, check the [`NAVITA_FOLLOW_ACTUAL_PATH`](#environment-variables) environment variable.

> [!NOTE]
> If this option is used, it should be the very first option given to Navita.

- Search syntax is same as the [FZF search syntax](https://junegunn.github.io/fzf/search-syntax/) except when searching for [Highest-ranked directory](#usual-directory-change). You can type in multiple search terms delimited by spaces. For example, FZF sees `^music .conf3$ sbtrkt !fire` as four separate search terms.

    | Token      | Match Type                              | Description                                          |
    | ---------- | --------------------------------------- | ---------------------------------------------------- |
    | `sbtrkt`   | fuzzy-match                             | Items that include `sbtrkt` characters in that order |
    | `'wild`    | exact-match (quoted)                    | Items that include `wild`                            |
    | `'wild'`   | exact-boundary-match (quoted both ends) | Items that include `wild` at word boundaries         |
    | `^music`   | prefix-exact-match                      | Items that start with `music`                        |
    | `.conf3$`  | suffix-exact-match                      | Items that end with `.conf3`                         |
    | `!fire`    | inverse-exact-match                     | Items that do not include `fire`                     |
    | `!^music`  | inverse-prefix-exact-match              | Items that do not start with `music`                 |
    | `!.conf3$` | inverrse-suffix-exact-match             | Items that do not end with `.conf3`                  | 

<div align="center"> 

## Dependencies

</div>

- [GNU Bash](http://tiswww.case.edu/php/chet/bash/bashtop.html) or [Zsh](https://www.zsh.org/)
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
wget2 https://raw.githubusercontent.com/CodesOfRishi/navita/main/navita.sh

# or using curl
curl https://raw.githubusercontent.com/CodesOfRishi/navita/main/navita.sh --output navita.sh
```

2. Source the `navita.sh` file in your `.bashrc`/`.zshrc` configuration file.

```bash
source "path/to/the/navita.sh"
```

<div align="center"> 

## Environment Variables

</div>

> [!NOTE]
> If you want to keep your desired values rather than the default ones, make sure to export these environment variables *before* sourcing the `navita.sh` file in your `.bashrc`/`.zshrc`.

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

- **NAVITA_RELATIVE_PARENT_PATH**
    - It defaults to `y` i.e., show the resolved parent paths relative to the present working directory in [Search & Traverse Parent Directories](search--traverse-parent-directories) feature.
    - Change it to `n` or `N` to show the parent paths as absolute path. 

- **NAVITA_SHOW_AGE**
    - It defaults to `y`, i.e., show an age annotation next to the paths while searching and traversing from history.
    - Change it to `n` or `N`, to not show an age annotation beside the paths.

- **NAVITA_FZF_EXACT_MATCH**
    - It defaults to `y`, i.e., Exact match and search in FZF when utilizing [Search & Traverse Child Directories](#search--traverse-child-directories), [Search & Traverse Parent Directories](#search--traverse-parent-directories) or [Search & Traverse History](#search--traverse-history).
    - Change it to `n` or `N`, to Fuzzy match and search in FZF.
    - It will not affect Tab completion in Bash or the [Highest-ranked directory search](#usual-directory-change).

- **NAVITA_MAX_AGE**
    - Specifies maximum retention period for a directory path since last access.
    - Navita determines the age of a directory based on its relative access time to the most recently accessed directory. If the most recent directory was accessed at time $a$ and another directory was accessed at time $(a+x)$, the age of the other directory is $x$ time units.
    - The default value is `90` i.e., 90 days.

- **NAVITA_DECAY_FACTOR**
    - The rate at which the score of older accesses decreases. A higher value results in a faster decay rate.
    - It defaults to `10`.

> [!WARNING]
> The decay factor should always be positive. Only adjust the decay factor if you are confident in the algorithm's behavior with the new value.


<div align="center"> 

### Non-Configurable Environment Variables

</div>

- **NAVITA_VERSION**
    - Navita's version information.

- **NAVITA_IGNOREFILE**
    - The file containing regular expression patterns to ignore matching paths from being added to the history.
    - The path to the file is `$NAVITA_CONFIG_DIR/navita-ignore`.

- **NAVITA_HISTORYFILE**
    - The file containing a history of directory paths visited using Navita, along with their associated metadata like frequency, access time, and score.
    - The path to the file is `$NAVITA_DATA_DIR/navita-history`.

<div align="center"> 

## Known Caveats

</div>

- Using suffix-exact-match FZF search syntax won't work in [Search & Traverse History](#search--traverse-history) if `NAVITA_SHOW_AGE` environment variable is set to `y` due to [FZF Issue #3983](https://github.com/junegunn/fzf/issues/3983).

<div align="center"> 

## Concept/Motivation

</div>

- To address the tedium of the builtin `cd` command.
- KISS&E - Keep It Simple, Straightforward & Efficient.
- No feature bloating.

<div align="center"> 

## Contributing to Navita

</div>

To review the latest changes that have not yet been included in the latest release, check out the [dev](https://github.com/CodesOfRishi/navita/tree/dev) branch.

<div align="center"> 

### Reporting Issues

</div>

If you encounter any bugs or issues while using Navita, please open an issue on the Navita GitHub repository. Provide as much detail as possible, including steps to reproduce the issue and any relevant error messages.

<div align="center"> 

## License

</div>

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) for details.
