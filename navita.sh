# ── Navita variables ──────────────────────────────────────────────────
export NAVITA_CONFIG_DIR="${NAVITA_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/navita}"
export NAVITA_HISTORYFILE="${NAVITA_CONFIG_DIR}/navita-history"
export NAVITA_HISTORYFILE_SIZE="${NAVITA_HISTORYFILE_SIZE:-50}"
export NAVITA_FOLLOW_ACTUAL_PATH="${NAVITA_FOLLOW_ACTUAL_PATH:-n}"
export NAVITA_COMMAND="${NAVITA_COMMAND:-cd}"

alias "${NAVITA_COMMAND}"="__navita__"

# ── create configuration file(s) for Navita ───────────────────────────
if [[ ! -d "${NAVITA_CONFIG_DIR}" ]]; then 
	mkdir -p "${NAVITA_CONFIG_DIR}"
	touch "${NAVITA_HISTORYFILE}"
	printf '%s\n' "Navita: Created ${NAVITA_HISTORYFILE}"
elif [[ ! -f "${NAVITA_HISTORYFILE}" ]]; then 
	touch "${NAVITA_HISTORYFILE}"
	printf '%s\n' "Navita: Created ${NAVITA_HISTORYFILE}"
fi

# Utility: Update History{{{
__navita::UpdatePathHistory() { 
	if [[ ! -s "${NAVITA_HISTORYFILE}" ]]; then 
		printf "%s\n" "${PWD}" > "${NAVITA_HISTORYFILE}"
	else
		sed -i "1i ${PWD}" "${NAVITA_HISTORYFILE}" 
	fi

	awk -i inplace '!seen[$0]++' "${NAVITA_HISTORYFILE}" # remove duplicates
	sed -i "$(( "${NAVITA_HISTORYFILE_SIZE}" + 1 )),\$"d "${NAVITA_HISTORYFILE}" # keep the navita-history file within the $NAVITA_HISTORYFILE_SIZE
	return $?
}
# }}}

# Utility: Validate Directory{{{
__navita::ValidateDirectory() {
	printf "%s" "$( find "${*}" -maxdepth 0 -exec cd {} \; 2>&1 >/dev/null )"
}
# }}}

# Utility: GetHistory{{{
__navita::GetHistory() {
	local get_pwd && get_pwd="${1:?The function needs to be told, if it\'s required to print PWD or not!}"
	local get_invalid_paths && get_invalid_paths="${2:?The function needs to be told, if it\'s required to print invalid paths or not!}"

	local line=""
	local pwd_removed="n"
	while read -r line; do
		if [[ ! "${get_pwd}" =~ ^(y|Y) ]] && [[ "${pwd_removed}" == "n" ]]; then
			if [[ "${line}" == "${PWD}" ]] || [[ "${line}" == "$( realpath -P ${PWD} )" ]]; then
				pwd_removed="y"
				continue
			fi
		fi

		if [[ "${get_invalid_paths}" =~ ^(y|Y) ]]; then
			printf "%s\n" "${line}"
		else
			[[ -z "$( __navita::ValidateDirectory "${line}" )" ]] && printf "%s\n" "${line}"
		fi
	done < "${NAVITA_HISTORYFILE}"
}
# }}}

# ── Feature: "Clean-History ───────────────────────────────────────────{{{
__navita::CleanHistory() { 

	# ── Feature: EmptyHistoryFile ─────────────────────────────────────────{{{
	__navita::CleanHistory::EmptyHistoryFile() {
		# +--------------------------------------------------------------------------------------------------+
		# | NOTE:                                                                                            |
		# | cp historyfile to tempfile                                                                       |
		# | empty the historyfile                                                                            |
		# | if success, cp tempfile to historyfile.bak & remove the tempfile                                 |
		# | if failed, remove the tempfile                                                                   |
		# +--------------------------------------------------------------------------------------------------+

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
	# }}}

	# ── Feature: RemoveInavlidPaths ───────────────────────────────────────{{{
	__navita::CleanHistory::RemoveInvalidPaths() {
		# +--------------------------------------------------------------------------------------------------+
		# | NOTE:                                                                                            |
		# | the line numbers that needs to be deleted from the history file, will be stored in an array      |
		# | using sed, delete those lines in-place                                                           |
		# +--------------------------------------------------------------------------------------------------+

		declare -a line_no_todel
		local line_no=1
		local line
		
		while read -r line; do
			local error && error="$( __navita::ValidateDirectory "${line}" )"
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
	# }}}

	printf '%s\n' "Choose any one: "
	printf '%s\n' "1. Remove only invalid paths."
	printf '%s\n' "2. Empty the history."
	printf "\n"
	local user_choice
	read -rp "Choice? (1 or 2): " user_choice
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
# }}}

# ── Feature: "Navigate-History ────────────────────────────────────────{{{
__navita::NavigateHistory() {
	local path_returned && path_returned=$( __navita::GetHistory "n" "n" | fzf --prompt="navita> " --select-1 --exit-0 --query="${*}" --preview="ls -lashFd --color=always {} && echo && ls -aFA --format=single-column --dereference-command-line-symlink-to-dir --color=always {}" )

	if [[ -z "${path_returned}" ]]; then 
		printf '%s\n' "Navita(info): none matched!"
	else
		builtin cd -L "${__the_builtin_P_option[@]}" "${path_returned}" || return $?
	fi
}
# }}}

# ── Feature: "Toggle-Last-Visits ──────────────────────────────────────{{{
__navita::ToggleLastVisits() {
	builtin cd -L "${__the_builtin_P_option[@]}" "${OLDPWD}" && __navita::UpdatePathHistory 
	return $?
}
# }}}

# ── Feature: "View-History ────────────────────────────────────────────{{{
__navita::ViewHistory() {
	local line=""
	while read -r line; do
		printf "%s ${colr91}%s${colr_rst}\n" "${line/#"${HOME}"/\~}" "$( __navita::ValidateDirectory "${line}" )"
	done < <( __navita::GetHistory "y" "y" ) | cat -n
}
# }}}

# ── Feature: "Navigate-Child-Dirs ─────────────────────────────────────{{{
__navita::NavigateChildDirs() {
	local fzf_query && fzf_query="${*:2}"
	local path_returned && path_returned=$( fzf --walker=dir,hidden,follow --prompt="navita> " --select-1 --exit-0 --query="${fzf_query}" --preview="ls -lashFd --color=always {} && echo && ls -aFA --format=single-column --dereference-command-line-symlink-to-dir --color=always {}" )

	if [[ -z "${path_returned}" ]]; then 
		printf '%s\n' "Navita(info): none matched!"
	else
		builtin cd -L "${__the_builtin_P_option[@]}" -- "${path_returned}" && __navita::UpdatePathHistory
		return $?
	fi
}
# }}}

# ── Feature: "CD-General ──────────────────────────────────────────────{{{
__navita::CDGeneral() {
	# +--------------------------------------------------------------------------------------------------+
	# | NOTE: if argument is either empty or already a legit directory path, then provide the argument   |
	# | to the builtin cd                                                                                |
	# | or else if the argument is already a valid existing option of the builtin cd, then provide the   |
	# | argument to the builtin cd                                                                       |
	# | otherwise provide the argument as a string to FZF to search the current directory                |
	# +--------------------------------------------------------------------------------------------------+

	local fzf_query=( "${@}" )

	if [[ -z "${fzf_query[*]}" ]]; then 
		# argument provided by the user is empty
		builtin cd -L "${__the_builtin_P_option[@]}" "${HOME}" && __navita::UpdatePathHistory 
		return $?
	elif [[ -d "${fzf_query[*]}" ]]; then
		# argument provided by the user is a valid directory path
		builtin cd -L "${__the_builtin_P_option[@]}" -- "${fzf_query[*]}" && __navita::UpdatePathHistory 
		return $?
	fi

	local path_returned && path_returned="$( find -L . -maxdepth 1 -type d | fzf --prompt="navita> " --select-1 --exit-0 --exact --query="${fzf_query[*]}" --preview="ls -lashFd --color=always {} && echo && ls -aFA --format=single-column --dereference-command-line-symlink-to-dir --color=always {}" )"

	case "$?" in
		0) 
			builtin cd -L  "${__the_builtin_P_option[@]}" -- "${path_returned}" && __navita::UpdatePathHistory;;
		1) printf "None matched!\n"; return 1;;
		2) return 2;;
		130) return 130;;
		*) return $?;;
	esac
}
# }}}

__navita__() {

	[[ "${NAVITA_FOLLOW_ACTUAL_PATH}" == "y" ]] && local __the_builtin_P_option && __the_builtin_P_option="-P"

	local colr91 && colr91='\e[01;91m'
	local colr_rst && colr_rst='\e[0m'

	local tput241 && tput241=$( tput setaf 241 )
	local tput_rst && tput_rst=$( tput sgr0 )

	case "$1" in
		"--") __navita::NavigateHistory "${@:2}";;
		"-") __navita::ToggleLastVisits;;
		"--history" | "-H") __navita::ViewHistory;;
		"--clean" | "-c") __navita::CleanHistory;;
		"--sub-search" | "-s") __navita::NavigateChildDirs "${@}";;
		"--root" | "-r") printf "Search & traverse in a root directory (to be implemented!)\n";;
		"--version" | "-v") printf "Print version information (to be implemented!)\n";;
		"--help" | "-h") printf "Print help information (to be implemented!)\n";;
		*) __navita::CDGeneral "${@}";;
	esac
}

