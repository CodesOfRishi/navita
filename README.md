<div align="center">

# Navita: Navigate Smarter, Not Harder

_Derived from "navigate" and "ita" (short for "iteration"), suggesting a tool that helps you navigate through iterations of directory visits._

[Features](#features) •
[Dependencies](#dependencies) •
[Installation](#installation)

</div>

**Streamline Your Workflow with Lightning-Fast Directory Switching!**

Tired of tedious navigation? Navita is here to revolutionize your command-line experience! The powerful Bash tool uses fuzzy search to get you to your destination in seconds.

**Work Faster, Not Longer**

Effortlessly jump between directories, subdirectories, and recent visits. Simplify your workflow and maximize productivity with Navita.

## Features
### Recursive Directory Search & Traversal

**Synopsis:** `cd (-s | --sub-search) <string>...`

Fuzzy search directories, all its subdirectories, and their subdirectories (so on..), and traverse to the selected one.

### History Search & Traversal

**Synopsis:** `cd -- [<string>...]`

Fuzzy search last 50 (default) visited directory paths and traverse to the selected one.
 
### Toggle Current & Previous Directories

 **Synopsis:** `cd -`

### View History

**Synopsis:** `cd (-H | --history)`

View last 50 (default) visited directory paths.

### Change to Directory

**Synopsis:** `cd [<string>...]`

Note: `cd` with no argument(s) will change PWD to $HOME.

### Cleanup History

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

