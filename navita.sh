# ── Navita variables ──────────────────────────────────────────────────
export NAVITA_CONFIG_DIR="${NAVITA_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/navita}"
export NAVITA_HISTORYFILE="${NAVITA_CONFIG_DIR}/navita-history"
export NAVITA_HISTORYFILE_SIZE="${NAVITA_HISTORYFILE_SIZE:-50}"
export NAVITA_FOLLOW_ACTUAL_PATH="${NAVITA_FOLLOW_ACTUAL_PATH:-n}"
export NAVITA_COMMAND="${NAVITA_COMMAND:-cd}"
export NAVITA_VERSION="Alpha"

alias "${NAVITA_COMMAND}"="__navita__"

# ── create configuration file(s) for Navita ───────────────────────────
if [[ ! -d "${NAVITA_CONFIG_DIR}" ]]; then 
	mkdir -p "${NAVITA_CONFIG_DIR}"
	touch "${NAVITA_HISTORYFILE}"
	printf "Navita: Created %s\n" "${NAVITA_HISTORYFILE}"
elif [[ ! -f "${NAVITA_HISTORYFILE}" ]]; then 
	touch "${NAVITA_HISTORYFILE}"
	printf "Navita: Created %s\n" "${NAVITA_HISTORYFILE}"
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

# ── Feature: ViewHistory ────────────────────────────────────────────{{{
__navita::ViewHistory() {
	local line
	while read -r line; do
		printf "%s" "${line}"
		if [[ "${line}" == "${PWD}" ]] || [[ "${line}" == "$( realpath -P "${PWD}" )" ]]; then
			printf "${colr_green}%s${colr_rst}" " ❰ Present Working Directory"
		elif [[ "${line}" == "${OLDPWD}" ]]; then
			printf "${colr_blue}%s${colr_rst}" " ❰ Previous Working Directory"
		else
			local path_error && path_error="$( __navita::ValidateDirectory "${line}" )"
			[[ -n "${path_error}" ]] && printf "${colr_red}%s${colr_rst}" " ❰ ${path_error#find: }"
		fi
		printf "\n"
	done < "${NAVITA_HISTORYFILE}"
}
# }}}

# ── Feature: CleanHistory ───────────────────────────────────────────{{{
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
			printf "%s cleaned.\n" "${NAVITA_HISTORYFILE}"
			$( whereis -b cp | cut -d" " -f2 ) "${tempfile}" "${NAVITA_HISTORYFILE}.bak"
			printf "Backup created at ${colr_grey}%s.bak${colr_rst}\n" "${NAVITA_HISTORYFILE}"
		fi
		rm --interactive=never "$tempfile"
		return "$exitcode"
	}
	# }}}

	# ── Feature: RemoveInvalidPaths ───────────────────────────────────────{{{
	__navita::CleanHistory::RemoveInvalidPaths() {
		# +--------------------------------------------------------------------------------------------------+
		# | NOTE:                                                                                            |
		# | the line numbers that needs to be deleted from the history file, will be stored in an array      |
		# | using sed, delete those lines in-place                                                           |
		# +--------------------------------------------------------------------------------------------------+

		local -a line_no_todel
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
			printf '%s deleted!\n' "${line_deleted}"
			sed -i -e "$(( "${i}" - "${index_reduced}" ))d" "${NAVITA_HISTORYFILE}"
			index_reduced=$(( "${index_reduced}" + 1 ))
		done
	}
	# }}}

	printf "Choose any one:\n"
	printf "1. Remove only invalid paths.\n"
	printf "2. Empty the history.\n"
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

# ── Feature: NavigateHistory ────────────────────────────────────────{{{
__navita::NavigateHistory() {
	local path_returned && path_returned=$( __navita::ViewHistory | fzf --prompt="navita> " --ansi --nth=1 --with-nth=1,2 --delimiter=" ❰ " --exact --select-1 --exit-0 --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {1} && echo && ls -CFaA --color=always {1}" )

	case "$?" in
		0) path_returned="${path_returned%% ❰ *}"; builtin cd -L "${__the_builtin_P_option[@]}" "${path_returned}";;
		1) printf "Navita(info): None matched!\n"; return 1;;
		*) return $?;;
	esac
}
# }}}

# ── Feature: ToggleLastVisits ──────────────────────────────────────{{{
__navita::ToggleLastVisits() {
	builtin cd -L "${__the_builtin_P_option[@]}" - && __navita::UpdatePathHistory 
}
# }}}

# ── Feature: NavigateChildDirs ─────────────────────────────────────{{{
__navita::NavigateChildDirs() {
	local path_returned && path_returned="$( find -L . -mindepth 2 -type d -not -path '*/.git/*' | fzf --select-1 --exit-0 --exact --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {} && echo && ls -CFaA --color=always {}" )"

	case "$?" in
		0) builtin cd -L "${__the_builtin_P_option[@]}" -- "${path_returned}" && __navita::UpdatePathHistory;;
		1) printf "Navita(info): None matched!\n"; return 1;;
		*) return $?;;
	esac
}
# }}}

# ── Feature: CDGeneral ──────────────────────────────────────────────{{{
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

	local path_returned && path_returned="$( find -L . -maxdepth 1 -mindepth 1 -type d | fzf --prompt="navita> " --select-1 --exit-0 --exact --layout=reverse --preview-window=down --border=bold --query="${fzf_query[*]}" --preview="ls -lashFd --color=always {} && echo && ls -CFaA --color=always {}" )"

	case "$?" in
		0) builtin cd -L  "${__the_builtin_P_option[@]}" -- "${path_returned}" && __navita::UpdatePathHistory;;
		1) __navita::NavigateHistory "${fzf_query[@]}";;
		*) return $?;;
	esac
}
# }}}

# ── Feature: NavigateParentDirs ───────────────────────────────────────{{{
__navita::NavigateParentDirs() {
	__navita::NavigateParentDirs::GetParentDirs() {
		__navita::NavigateParentDirs::GetParentDirs::GetParentNodes() {
			local _dir && _dir="${PWD}"
			[[ "${_dir}" == "/" ]] && return 0

			until [[ -z "${_dir}" ]]; do
				_dir="${_dir%/*}"
				[[ -n "${_dir}" ]] && printf "%s\n" "${_dir}"
			done
			printf "/\n"
		}

		while read -r line; do
			find -L "${line}" -maxdepth 1 -mindepth 1 -type d
		done < <(__navita::NavigateParentDirs::GetParentDirs::GetParentNodes) | fzf --prompt="navita> " --exact --select-1 --exit-0 --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {} && echo && ls -CFaA --color=always {}"
	}

	local path_returned && path_returned="$( __navita::NavigateParentDirs::GetParentDirs "${@}" )"

	case "$?" in
		0) builtin cd -L  "${__the_builtin_P_option[@]}" -- "${path_returned}" && __navita::UpdatePathHistory;;
		1) printf "Navita(info): None matched!\n"; return 1;;
		*) return $?;;
	esac
}
# }}}

# ── Feature: VersionInfo ─────────────────────────────────────────────{{{
__navita::Version() {
	printf "Navita - %s\n" "${NAVITA_VERSION}"
}
# }}}

__navita__() {

	[[ "${NAVITA_FOLLOW_ACTUAL_PATH}" =~ ^(y|Y)$ ]] && local __the_builtin_P_option && __the_builtin_P_option="-P"

	local colr_red && colr_red='\033[1;38;2;255;51;51m'
	local colr_green && colr_green="\033[1;38;2;91;255;51m"
	local colr_grey && colr_grey="\033[1;38;2;122;122;122m"
	local colr_blue && colr_blue="\033[1;38;2;0;150;255m"
	local colr_rst && colr_rst='\e[0m'

	case "$1" in
		"--") __navita::NavigateHistory "${@:2}";;
		"-") __navita::ToggleLastVisits;;
		"--history" | "-H") __navita::ViewHistory;;
		"--clean" | "-c") __navita::CleanHistory;;
		"--sub-search" | "-s") __navita::NavigateChildDirs "${@:2}";;
		"--super-search" | "-S" ) __navita::NavigateParentDirs "${@:2}";;
		"--root" | "-r") printf "Search & traverse in a root directory (to be implemented!)\n";;
		"--version" | "-v") __navita::Version;;
		"--help" | "-h") printf "Print help information (to be implemented!)\n";;
		*) __navita::CDGeneral "${@}";;
	esac
}

