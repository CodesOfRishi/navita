# TODO:
# Colorize informational outputs
# Add an `--help`/`-h` option that display a brief helpful information
# 	- can make use of `builtin cd -h`
# Allow users to customize options for Navita.
# Make use of programs based on availability, i.e., check which program is available and then use that program
# 	- cat or bat
# 	- find or fd-find
# 	- grep or rg

# NOTE: Why Navita?
# Fast
# Efficient
# Easy cutomization
# Written in !! only lines of code.

# Navita variables
export NAVITA_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/navita"
export NAVITA_HISTORYFILE="${NAVITA_CONFIG_DIR}/path-history"
export NAVITA_HISTORYFILE_SIZE="${NAVITA_HISTORYFILE_SIZE:=50}"

alias "${NAVITA_COMMAND:="cd"}"="__navita__"

# create configuration file(s) for Navita
if [[ ! -d "${NAVITA_CONFIG_DIR}" ]]; then 
	mkdir -p "${NAVITA_CONFIG_DIR}"
	touch "${NAVITA_HISTORYFILE}"
	printf '%s\n' "Navita: Created ${NAVITA_HISTORYFILE}"
elif [[ ! -f "${NAVITA_HISTORYFILE}" ]]; then 
	touch "${NAVITA_HISTORYFILE}"
	printf '%s\n' "Navita: Created ${NAVITA_HISTORYFILE}"
fi

__navita::PrintHistory() { 

	local line=""
	while read -r line; do
		printf '%s' "${line/#"${HOME}"/\~}"
		local error && error="$( find "${line}" -maxdepth 0 -exec cd {} \; 2>&1 >/dev/null )"
		if [[ -n "${error}" ]]; then 
			printf " (${colr91}${error}${colr_rst})"
		fi
		printf "\n"
	done < "${NAVITA_HISTORYFILE}"
}

__navita::CleanHistory() { 

	__navita::CleanHistory::EmptyHistoryFile() {
		# NOTE:
		# cp historyfile to tempfile
		# empty the historyfile
		# if success, cp tempfile to historyfile.bak & remove the tempfile
		# if failed, remove the tempfile

		local tempfile && tempfile=$( mktemp )
		$( whereis -b cp | cut -d" " -f2 ) "${NAVITA_HISTORYFILE}" "${tempfile}"
		> "${NAVITA_HISTORYFILE}"
		local exitcode="$?"
		if [[ "${exitcode}" -eq 0 ]]; then 
			printf '%s\n' "${NAVITA_HISTORYFILE} cleaned."
			$( whereis -b cp | cut -d" " -f2 ) "${tempfile}" "${NAVITA_HISTORYFILE}.bak"
			printf '%s\n' "Backup created at ${tput241}${NAVITA_HISTORYFILE}.bak${tput_rst}"
		fi
		rm --interactive=never "$tempfile"
		return "$exitcode"
	}

	__navita::CleanHistory::RemoveInvalidPaths() {
		# NOTE:
		# the line numbers that needs to be deleted from the history file, will be stored in an array
		# using sed, delete those lines in-place

		declare -a line_no_todel
		local line_no=1
		local line
		
		while read -r line; do
			local error && error="$( find "${line}" -maxdepth 0 -exec cd {} \; 2>&1 >/dev/null )"
			if [[ -n "${error}" ]]; then 
				line_no_todel+=( "${line_no}" )
			fi
			line_no=$(( "${line_no}" + 1 ))
		done < "${NAVITA_HISTORYFILE}"

		local index_reduced=0
		for i in "${line_no_todel[@]}"; do
			local line_deleted && line_deleted=$( sed -n "$(( "${i}" - "${index_reduced}" ))p" "${NAVITA_HISTORYFILE}" )
			printf '%s\n' "${line_deleted} deleted!"
			sed -i -e "$(( "${i}" - "${index_reduced}" ))d" "${NAVITA_HISTORYFILE}"
			index_reduced=$(( "${index_reduced}" + 1 ))
		done
	}

	printf '%s\n' "Choose any one: "
	printf '%s\n' "1. Remove only invalid paths."
	printf '%s\n' "2. Empty the history."
	printf "\n"
	local user_choice
	read -p "Choice? (1 or 2): " user_choice
	printf "\n"

	if [[ "${user_choice}" -eq 1 ]]; then
		__navita::CleanHistory::RemoveInvalidPaths
	elif [[ "${user_choice}" -eq 2 ]]; then
		__navita::CleanHistory::EmptyHistoryFile
	else
		printf "Invalid input!\n" 1>&2
		return 1
	fi
	return $?
}

# update the path-history file
__navita::UpdatePathHistory() { 
	if [[ ! -s "${NAVITA_HISTORYFILE}" ]]; then 
		printf "${PWD}\n" > "${NAVITA_HISTORYFILE}"
	else
		sed -i "1i ${PWD}" "${NAVITA_HISTORYFILE}" 
	fi

	awk -i inplace '!seen[$0]++' "${NAVITA_HISTORYFILE}" # remove duplicates
	sed -i "$(( "${NAVITA_HISTORYFILE_SIZE}" + 1 )),\$"d "${NAVITA_HISTORYFILE}" # keep the path-history file within the $NAVITA_HISTORYFILE_SIZE
	return $?
}

__navita__() {

	local colr91 && colr91='\e[01;91m'
	local colr_rst && colr_rst='\e[0m'

	local tput241 && tput241=$( tput setaf 241 )
	local tput_rst && tput_rst=$( tput sgr0 )

	if [[ $1 == "--" ]]; then
		# NOTE: "Navigate-History"
		local fzf_query && fzf_query="${*:2}"
		local path_returned && path_returned=$( cat "${NAVITA_HISTORYFILE}"  | fzf --prompt="navita> " --select-1 --exit-0 --query="${fzf_query}" --preview="ls -lashFd --color=always {} && echo && ls -aFA --format=single-column --dereference-command-line-symlink-to-dir --color=always {}" )

		if [[ -z "${path_returned}" ]]; then 
			printf '%s\n' "Navita(info): none matched!"
		else
			builtin cd "${path_returned}" || return $?
		fi
	elif [[ $1 == "-" ]]; then
		# NOTE: "Toggle-Last-Visits"
		builtin cd "${OLDPWD}" && __navita::UpdatePathHistory 
		return $?
	elif [[ $1 == "--history" ]] || [[ $1 == "-H" ]]; then
		# NOTE: "View-History"
		__navita::PrintHistory | cat -n
	elif [[ $1 == "--clean" ]] || [[ $1 == "-c" ]]; then
		# NOTE: "Clean-History"
		__navita::CleanHistory
	elif [[ $1 == "--sub-search" ]] || [[ $1 == "-s" ]]; then
		# NOTE: "Navigate-Child-Dirs"
		local fzf_query && fzf_query="${*:2}"
		local path_returned && path_returned=$( fzf --walker=dir,hidden,follow --prompt="navita> " --select-1 --exit-0 --query="${fzf_query}" --preview="ls -lashFd --color=always {} && echo && ls -aFA --format=single-column --dereference-command-line-symlink-to-dir --color=always {}" )

		if [[ -z "${path_returned}" ]]; then 
			printf '%s\n' "Navita(info): none matched!"
		else
			builtin cd "${path_returned}" || return $?
		fi
	else
		# NOTE: "CD-GENERAL"
		# NOTE: if argument is either empty or already a legit directory path, then provide the argument to the builtin cd
		# or else if the argument is already a valid existing option of the builtin cd, then provide the argument to the builtin cd
		# otherwise provide the argument as a string to FZF to search the current directory

		local fzf_query=( "${@}" )

		if [[ -z "${fzf_query[*]}" ]]; then 
			# NOTE: argument provided by the user is empty
			builtin cd "${HOME}" && __navita::UpdatePathHistory 
			return $?
		elif [[ -d "${fzf_query[*]}" ]]; then
			# NOTE: argument provided by the user is a valid directory path
			builtin cd "${fzf_query[*]}" && __navita::UpdatePathHistory 
			return $?
		fi

		if [[ "${fzf_query[0]:0:2}" == "-L" ]] || [[ "${fzf_query[0]:0:2}" == "-P" ]] || [[ "${fzf_query[0]:0:2}" == "-e" ]] || [[ "${fzf_query[0]:0:2}" == "-@" ]] || [[ "${fzf_query[0]:0:6}" == "--help" ]]; then
			# NOTE: argument provided by the user likely contains (valid/invalid) builtin cd options (check builtin cd --help)
			local cderror && cderror="$( find -L -maxdepth 1 -exec cd "${fzf_query[@]}" \; 2>&1 > /dev/null )"

			if [[ -z "${cderror[*]}" ]]; then 
				# NOTE: likely argument contains valid existing option(s) of builtin cd
				builtin cd "${fzf_query[@]}" && __navita::UpdatePathHistory 
				return $?
			fi
		fi

		# NOTE: argument is not empty, is not valid directory path and also does not contains a valid builtin cd option
		local path_returned && path_returned="$( find -L -maxdepth 1 -type d | fzf --prompt="navita> " --select-1 --exit-0 --exact --query="${fzf_query[*]}" --preview="ls -lashFd --color=always {} && echo && ls -aFA --format=single-column --dereference-command-line-symlink-to-dir --color=always {}" )"

		if [[ -z "${path_returned}" ]]; then
			printf "None matched!\n"
		else
			builtin cd "${path_returned}" && __navita::UpdatePathHistory 
			return $?
		fi
	fi
}

