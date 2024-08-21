# Todos

## README

- Add info about Navita's search matching preference in README.
    - match substring closer to the end of the path 
    - match most recent paths.
- Add information about FZF search syntax in README.
- If associative arrays are used, then mention Bash version 4 or later as requirement in README.
- Add a section that tells the differences with SmartCD in README.
- Add information about individual feature functions in README.

## navita.sh

- Introduce environment variables to toggle path age, Navita annotations and user-specific annotations.
- Check the following FZF options/features - 
    - `--filepath-word`
    - `--jump-labels=CHARS`
    - `--info=STYLE`
    - `--info-command=COMMAND`
    - `--header=STR`
    - Key/event bindings
    - Available Actions
    - Command Execution
- Use associative array (key-value data structure) to contain list of paths (as keys) and annotation (as values) to show up in history.
    - Move existing annotation to this array.
- Introduce features related to exclusions.
    - List of directories to exclude from being searched (E.g. - .git).
    - Exclude directories from being added to the history file, but allow being searched.
- Introduce a feature to remove multiple paths from history using FZF multi-select
- ~~Introduce a feature for tab completion. When `-` is the first argument with the cursor just at right-side of the `-`, it should bring an FZF list of Navita options for completion. In other cases, it should perform completion for directories in PWD.~~
- ~~For Navigate-Child-Dirs, search from only 2nd level directories.~~
- ~~Keep consistency in coloring codes - use ASCII color codes instead of `tput`.~~
- ~~Implement FZF <u>exact</u> search/match for Navigate-History.~~
- Colorize informational outputs.
- Introduce `--root` / `-r` option, which will fuzzy search in the directory path provided to the --root option.
    - Don't search PWD and invalid path in FZF for the `--root` option.
- Allow users to customize options for Navita.
    - Use `eval` to execute commands, where you require customizibility of those commands by the end-user.
- Make use of programs based on availability, i.e., check which program is available and then use that program
    - `cat` or `bat`
    - `find` or `fd-find`
    - `grep` or `rg`
- ~~Add parent directory search & traversal feature.~~
    - Parent search should not be beyond $HOME until explicitly specified.
    - Allow `..` option as well for <b>NavigateParentDirs</b>.
- Add an `--help`/`-h` option that display a brief helpful information
    - can make use of `builtin cd -h`
- Try implementing frecency algorithm.
    - ~~Checkout the following options of FZF - `--scheme=history`~~
    - Implement Aging feature for Navita.
        - ~~Show how long ago a path was accessed in history.~~
        - Remove invalid paths from the history automatically if they are older than N days (likely 90 days).
            - Allow the end-users to make use of the invidual function responsible for aging. This can allow users to put the function in `~/.bash_logout`, so that the older paths (>= 90 days) will be removed just before logging off.

# When to do nothing?

- in case fzf is interrupted with CTRL-c or ESC (obviously by the uer), don't do anything. (fzf exit code 130)
- in case no match was found from fzf, don't do anything. (fzf exit code 1)
- in case there was an fzf error, throw error and do nothing. (fzf exit code 2)

# Function Logics

## validatePossibleGroupedOptions()

- If Navita won't handle the builtin cd's `-P` and `-L` options together.

```bash
colr91='\e[01;91m'
colr_rst='\e[0m'

opt="sP"

if [[ "${opt}" =~ (sS|Ss|PL|LP) ]]; then
	# TEST: 0
	printf "TEST-0\n"
	printf "${colr91}Inavlid option${colr_rst}: %s\n" "${opt}"
elif [[ "${opt}" =~ [^(P|L)(s|S)]+ ]]; then
	# TEST: 1
	printf "TEST-1\n"
	printf "${colr91}Inavlid option${colr_rst}: %s\n" "${opt}"
else
	# TEST: 3
	printf "TEST-3\n"
	printf "Valid option: %s\n" "${opt}"
fi
```

- If Navita will handle the builtin cd's `-P` and `-L` options together.

```bash
colr91='\e[01;91m'
colr_rst='\e[0m'

opt="sP"

if [[ "${opt}" =~ (sS|Ss) ]]; then
	# TEST: 0
	printf "TEST-0\n"
	printf "${colr91}Inavlid option${colr_rst}: %s\n" "${opt}"
elif [[ "${opt}" =~ [^PL(s|S)]+ ]]; then
	# TEST: 1
	printf "TEST-1\n"
	printf "${colr91}Inavlid option${colr_rst}: %s\n" "${opt}"
else
	# TEST: 3
	printf "TEST-3\n"
	printf "Valid option: %s\n" "${opt}"
fi
```

## validatePossibleGroupedOptions()

```bash
validatePossibleGroupedOptions() {
	# possibility of -P, -L, -S, -s being grouped
	# if valid option will print the overall valid option grouped together.
	# return 0 (no/invalid options)
	# return 1 (valid option with sub-dir option)
	# return 2 (valid option with parent-dir option)
	# return 3 (valid with neither sub-dir nor parent-dir option)
}
```

## POSIX-PL-OptionTraversal()

```bash
POSIX-PL-OptionTraversal() {
	# local opt
	# if valid grouped option contains P, assign "p" to opt
	# if valid grouped option contains L, assgn "L" to opt
	# if valid grouped optoin contains both P & L, assign PL to opt (here order matters)
}
```

## getParentDirPath()

```bash
getParentDirPath() {
	# will print the parent dir path from FZF's fuzzy search & match
	# return 0 (successful match)
	# return 1 (fzf no match)
	# return 2 (fzf error)
	# return 130 (interrupted with CTRL-c or ESC)
}
```

## getSubDirPath()

```bash
getSubDirPath() {
	# will print the sub dir path from FZF's fuzzy search & match
	# return 0 (successful match)
	# return 1 (fzf no match)
	# return 2 (fzf error)
	# return 130 (interrupted with CTRL-c or ESC)
}
```
