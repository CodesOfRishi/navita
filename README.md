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

### Recursive Directory Search & Traversal

_Feature name: Navigate-Child-Dirs_

**Synopsis:** `cd (-s | --sub-search) <string>...`

Fuzzy search directories, all its subdirectories, and their subdirectories (so on..), and traverse to the selected one.

### History Search & Traversal

_Feature name: Navigate-History_

**Synopsis:** `cd -- [<string>...]`

Fuzzy search last 50 (default) visited directory paths and traverse to the selected one.
 
### Toggle Current & Previous Directories

_Feature name: Toggle-Last-Visits_

**Synopsis:** `cd -`

Switch between the current directory and the previous directory. 

### View History

_Feature name: View-History_

**Synopsis:** `cd (-H | --history)`

View last 50 (default) visited directory paths.

### Change to Directory

_Feature name: CD-General_

**Synopsis:** `cd [<string>...]`

Note: `cd` with no argument(s) will change PWD to $HOME.

### Cleanup History

_Feature name: Clean-History_

**Synopsis:** `cd (-c | --cleanup)`

This is will give an option to either remove invalid paths from the history or completely empty the history.

## Dependencies

- [FZF](https://junegunn.github.io/fzf/)
- [GNU Core Utilities](https://www.gnu.org/software/coreutils/)

## Installation

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

