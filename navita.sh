# ── Navita variables ──────────────────────────────────────────────────
export NAVITA_DATA_DIR="${NAVITA_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/navita}"
export NAVITA_HISTORYFILE="${NAVITA_DATA_DIR}/navita-history"
export NAVITA_HISTORYFILE_SIZE="${NAVITA_HISTORYFILE_SIZE:-50}"
export NAVITA_FOLLOW_ACTUAL_PATH="${NAVITA_FOLLOW_ACTUAL_PATH:-n}"
export NAVITA_COMMAND="${NAVITA_COMMAND:-cd}"
export NAVITA_VERSION="Alpha"

alias "${NAVITA_COMMAND}"="__navita__"

# ── create configuration file(s) for Navita ───────────────────────────
if [[ ! -d "${NAVITA_DATA_DIR}" ]]; then 
	mkdir -p "${NAVITA_DATA_DIR}"
	touch "${NAVITA_HISTORYFILE}"
	printf "Navita: Created %s\n" "${NAVITA_HISTORYFILE}"
elif [[ ! -f "${NAVITA_HISTORYFILE}" ]]; then 
	touch "${NAVITA_HISTORYFILE}"
	printf "Navita: Created %s\n" "${NAVITA_HISTORYFILE}"
fi

# Utility: Update History{{{
__navita::UpdatePathHistory() { 
	if [[ ! -s "${NAVITA_HISTORYFILE}" ]]; then 
		printf "%s : %d\n" "${PWD}" "$( date +%s )" > "${NAVITA_HISTORYFILE}"
	else
		sed -i "1i ${PWD} : $( date +%s )" "${NAVITA_HISTORYFILE}" 
	fi

	awk -i inplace -F " : " '!seen[$1]++' "${NAVITA_HISTORYFILE}" # remove duplicate paths
	sed -i "$(( "${NAVITA_HISTORYFILE_SIZE}" + 1 )),\$"d "${NAVITA_HISTORYFILE}" # keep the navita-history file within the $NAVITA_HISTORYFILE_SIZE
}
# }}}

# Utility: Validate Directory{{{
__navita::ValidateDirectory() {
	printf "%s" "$( find "${*}" -maxdepth 0 -exec cd {} \; 2>&1 >/dev/null )"
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
			line="${line%% : *}"
			local error && error="$( __navita::ValidateDirectory "${line}" )"
			if [[ -n "${error}" ]]; then 
				line_no_todel+=( "${line_no}" )
			fi
			line_no=$(( "${line_no}" + 1 ))
		done < "${NAVITA_HISTORYFILE}"

		local index_reduced=0
		local i
		for i in "${line_no_todel[@]}"; do
			local line_to_be_deleted && line_to_be_deleted=$( sed -n "$(( "${i}" - "${index_reduced}" ))p" "${NAVITA_HISTORYFILE}" )
			sed -i -e "$(( "${i}" - "${index_reduced}" ))d" "${NAVITA_HISTORYFILE}" && \
				printf '%s deleted!\n' "${line_to_be_deleted%% : *}" &&\
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

# ── Feature: ViewHistory ────────────────────────────────────────────{{{
__navita::ViewHistory() {
	local line
	local now_time && now_time="$( date +%s )"
	while read -r line; do
		local _path && _path="${line%% : *}"
		printf "%s" "${_path}" 

		local access_time && access_time="${line##* : }"
		local seconds_old && seconds_old="$(( ${now_time} - ${access_time} ))"
		local days_old && days_old="$(( ${seconds_old}/86400 ))"
		local hours_old && hours_old="$(( (${seconds_old} - (${days_old}*86400))/3600 ))"
		local minutes_old && minutes_old="$(( (${seconds_old} - (${days_old}*86400) - (${hours_old}*3600))/60 ))"

		local path_age=""
		[[ "${days_old}" -gt 0 ]] && path_age="${days_old}d"
		[[ "${hours_old}" -gt 0 ]] && path_age="${path_age}${hours_old}h"
		[[ "${minutes_old}" -gt 0 ]] && path_age="${path_age}${minutes_old}m"

		[[ -n "${path_age}" ]] && printf "${colr_grey} ❰ %s${colr_rst}" "${path_age}"

		if [[ "${_path}" == "${PWD}" ]] || [[ "${_path}" == "$( realpath -P "${PWD}" )" ]]; then
			printf "${colr_green}%s${colr_rst}" " ❰ Present Working Directory"
		elif [[ "${_path}" == "${OLDPWD}" ]]; then
			printf "${colr_blue}%s${colr_rst}" " ❰ Previous Working Directory"
		else
			local path_error && path_error="$( __navita::ValidateDirectory "${_path}" )"
			[[ -n "${path_error}" ]] && printf "${colr_red}%s${colr_rst}" " ❰ ${path_error#find: }"
		fi
		printf "\n"
	done < "${NAVITA_HISTORYFILE}"
}
# }}}

# ── Feature: NavigateHistory ────────────────────────────────────────{{{
__navita::NavigateHistory() {
	local path_returned && path_returned=$( __navita::ViewHistory | fzf --prompt="navita> " --tiebreak=end,index --scheme=history --ansi --nth=1 --with-nth=1,2,3 --delimiter=" ❰ " --exact --select-1 --exit-0 --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {1} && echo && ls -CFaA --color=always {1}" )

	case "$?" in
		0) path_returned="${path_returned%% ❰ *}"; builtin cd -L "${__the_builtin_P_option[@]}" "${path_returned}" && __navita::UpdatePathHistory;;
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
	local path_returned && path_returned="$( find -L . -mindepth 2 -type d -not -path '*/.git/*' | fzf --tiebreak=end,index --scheme=history --select-1 --exit-0 --exact --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {} && echo && ls -CFaA --color=always {}" )"

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

	if [[ -z "${*}" ]]; then 
		# argument provided by the user is empty
		builtin cd -L "${__the_builtin_P_option[@]}" "${HOME}" && __navita::UpdatePathHistory 
		return $?
	elif [[ -d "${*}" ]]; then
		# argument provided by the user is a valid directory path
		builtin cd -L "${__the_builtin_P_option[@]}" -- "${*}" && __navita::UpdatePathHistory 
		return $?
	fi

	local path_returned && path_returned="$( find -L . -maxdepth 1 -mindepth 1 -type d | fzf --prompt="navita> " --tiebreak=end,index --scheme=history --select-1 --exit-0 --exact --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {} && echo && ls -CFaA --color=always {}" )"

	case "$?" in
		0) builtin cd -L  "${__the_builtin_P_option[@]}" -- "${path_returned}" && __navita::UpdatePathHistory;;
		1) __navita::NavigateHistory "${@}";;
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
		done < <(__navita::NavigateParentDirs::GetParentDirs::GetParentNodes) | fzf --prompt="navita> " --tiebreak=end,index --scheme=history --exact --select-1 --exit-0 --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {} && echo && ls -CFaA --color=always {}"
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

# ── Feature: TabCompletion ────────────────────────────────────────────{{{
__navita::completions() {
	if [[ "${COMP_CWORD}" -eq 1 ]] && [[ "${COMP_WORDS[COMP_CWORD]}" =~ ^- ]]; then
		local navita_opts && navita_opts="$( printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n" "-" "--" "-H" "--history" "-c" "--clean" "-s" "--sub-search" "-S" "--super-search" "-v" "--version" | \
			fzf --prompt="navita> " --tiebreak=begin,index --scheme=history --select-1 --exit-0 --exact --layout=reverse --query="${COMP_WORDS[COMP_CWORD]}" --bind=tab:down,btab:up )"

		case "$?" in
			0) COMPREPLY=( "${navita_opts}" );;
			*) 
				local dir_select && dir_select="$( compgen -d -- "${COMP_WORDS[COMP_CWORD]}" | \
					fzf --prompt="navita> " --tiebreak=begin,index --scheme=history --select-1 --exit-0 --exact --layout=reverse --query="${COMP_WORDS[COMP_CWORD]}" --bind=tab:down,btab:up --preview-window=down --border=bold --preview="bash -c 'ls -lashFd --color=always -- \"\${1/#~/${HOME}}\" && echo && ls -CFaA --color=always -- \"\${1/#~/${HOME}}\"' -- {}" )"

				case "$?" in
					0) COMPREPLY=( "${dir_select}" );;
					*) return 0;;
				esac
				;;
		esac
	else
		local dir_select && dir_select="$( compgen -d -- "${COMP_WORDS[COMP_CWORD]}" | \
			fzf --prompt="navita> " --tiebreak=begin,index --scheme=history --select-1 --exit-0 --exact --layout=reverse --query="${COMP_WORDS[COMP_CWORD]}" --bind=tab:down,btab:up --preview-window=down --border=bold --preview="bash -c 'ls -lashFd --color=always -- \"\${1/#~/${HOME}}\" && echo && ls -CFaA --color=always -- \"\${1/#~/${HOME}}\"' -- {}" )"
		
		case "$?" in
			0) COMPREPLY=( "${dir_select}" );;
			*) return 0;;
		esac
	fi
}

complete -F __navita::completions "${NAVITA_COMMAND}"
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
		"--history" | "-H") __navita::ViewHistory;;
		"-") __navita::ToggleLastVisits;;
		"--clean" | "-c") __navita::CleanHistory;;
		"--sub-search" | "-s") __navita::NavigateChildDirs "${@:2}";;
		"--super-search" | "-S" ) __navita::NavigateParentDirs "${@:2}";;
		"--root" | "-r") printf "Search & traverse in a root directory (to be implemented!)\n";;
		"--version" | "-v") __navita::Version;;
		"--help" | "-h") printf "Print help information (to be implemented!)\n";;
		*) __navita::CDGeneral "${@}";;
	esac
}

# update the history with the current working directory when opening a new shell
__navita::UpdatePathHistory

