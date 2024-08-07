<div align="center">

# Navita: Navigate Smarter, Not Harder

_Derived from "navigate" and "ita" (short for "iteration"), suggesting a tool that helps you navigate through iterations of directory visits._

[Features](#features) •
[Dependencies](#dependencies) •
[Installation](#installation)

</div>

**Tired of typing out long, complex directory paths?** Navita is here to simplify your command-line experience! The powerful Bash tool uses fuzzy search to get you to your destination in seconds.

**Forget about tedious typing.** You can instantly find and jump to any directory, no matter how deeply nested. Navita is a great tool for boosting your productivity and saving you valuable time.

<div align="center">

## Features

</div>

<div align="center">

### Recursive Directory Search & Traversal

*Feature name: Navigate-Child-Dirs*

</div>

**Synopsis:** `cd (-s | --sub-search) [<string>...]`

Fuzzy search directories, all its subdirectories, and their subdirectories (so on..), and traverse to the selected one.

<div align="center">

### History Search & Traversal

*Feature name: Navigate-History*

</div>

**Synopsis:** `cd -- [<string>...]`

Fuzzy search last 50 (default) visited directory paths and traverse to the selected one.

<div align="center">

### View History

*Feature name: View-History*

</div>

**Synopsis:** `cd (-H | --history)`

View last 50 (default) visited directory paths.

<div align="center">

### Change to Directory

*Feature name: CD-General*

</div>

**Synopsis:** `cd [<string>...]`

Fuzzy search directories *in current working directory* and traverse to the selected one.

<div align="center">

### Toggle Current & Previous Directories

*Feature name: Toggle-Last-Visits*

</div>

**Synopsis:** `cd -`

Switch between the current directory and the previous directory. 

<div align="center">

### Cleanup History

*Feature name: Clean-History*

</div>

**Synopsis:** `cd (-c | --cleanup)`

This is will give an option to either remove invalid paths from the history or completely empty the history.

<div align="center">

## Dependencies

</div>

- [FZF](https://junegunn.github.io/fzf/)
- [GNU Sed](https://sed.sourceforge.io/)
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

