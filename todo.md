# Todos

- Keep consistency in coloring codes.
- Introduce a feature to add directories to a list, so that they are not added to the history
- Introduce a feature to remove multiple paths from history using FZF multi-select
- ~~Implement FZF <u>exact</u> search/match for Navigate-History.~~
- Use exec to execute commands, where you require customizibility of those commands by the end-user.
- Show relevant error (if any) along side each path as well in FZF which search/matching for paths.
- Don't search PWD and invalid path in FZF for the `--root` option.
- Make listing of directories in FZF preview in column format and configure the FZF display with its preview at the bottom.
- ~~Make CD-General search the history if no match was found from the $PWD/.~~
- Check out `command` command and see if it can be used to check a command's availablitiy for Navita.
- ~~Keep support for only POSIX builtin cd options.~~
- ~~Use `-maxdepth 0` of the `find` command wherever you are only validating successful execution of the builtin cd command.~~
- ~~Utilize FZF exit statuses.~~
- Colorize informational outputs.
- Add an `--help`/`-h` option that display a brief helpful information
    - can make use of `builtin cd -h`
- Introduce `--root` / `-r` option, which will fuzzy search in the directory path provided to the --root option.
- Allow users to customize options for Navita.
- Make use of programs based on availability, i.e., check which program is available and then use that program
    - `cat` or `bat`
    - `find` or `fd-find`
    - `grep` or `rg`
- Add parent directory search & traversal feature.
    - Parent search should not be beyond $HOME until explicitly specified.
    ```bash
    parentDirs() {
        local parentdir="$PWD/.config/nvim/.lua"
        # local parentdir="/"
        [[ "${parentdir}" == "/" ]] && return 0
        # printf "OrigPWD: %s\n" "${parentdir}"
        # printf "ModiPWD: %s\n" "${parentdir%/*}"

        until [[ -z "${parentdir}" ]]; do
            parentdir="${parentdir%/*}"
            [[ ! -z "${parentdir}" ]] && printf "Parent Dir: %s\n" "${parentdir}"
        done

        printf "Parent Dir: /\n"

    }

    parentDirs
    ```
- Add Apache 2.0 License
- Add an environment containing version name
- Introduce `-v`/`--version` options to show version information
- Add a section that tells the differences with SmartCD in README
- Remove invalid paths from the history automatically if they are older than N days (likely 90 days).
- Implement Aging feature for Navita.

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
