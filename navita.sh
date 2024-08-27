# Copyright 2024 Rishi Kumar
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ── Navita variables ──────────────────────────────────────────────────
export NAVITA_DATA_DIR="${NAVITA_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/navita}"
export NAVITA_HISTORYFILE="${NAVITA_DATA_DIR}/navita-history"
export NAVITA_FOLLOW_ACTUAL_PATH="${NAVITA_FOLLOW_ACTUAL_PATH:-n}"
export NAVITA_COMMAND="${NAVITA_COMMAND:-cd}"
export NAVITA_MAX_AGE="${NAVITA_MAX_AGE:-30}"
export NAVITA_AUTOMATIC_EXPIRE_PATHS="y"
export NAVITA_VERSION="Alpha"
export NAVITA_CONFIG_DIR="${NAVITA_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/navita}"
export NAVITA_IGNOREFILE="${NAVITA_CONFIG_DIR}/navita-ignore"

alias "${NAVITA_COMMAND}"="__navita__"

# ── Create data file(s) for Navita ────────────────────────────────────
if [[ ! -d "${NAVITA_DATA_DIR}" ]]; then 
	mkdir -p "${NAVITA_DATA_DIR}"
	printf "Navita: Created %s\n" "${NAVITA_DATA_DIR}"
fi
if [[ ! -f "${NAVITA_HISTORYFILE}" ]]; then 
	touch "${NAVITA_HISTORYFILE}"
	printf "Navita: Created %s\n" "${NAVITA_HISTORYFILE}"
fi

# ── Create configuration file(s) for Navita ───────────────────────────
if [[ ! -d "${NAVITA_CONFIG_DIR}" ]]; then
	mkdir -p "${NAVITA_CONFIG_DIR}"
	printf "Navita: Created %s\n" "${NAVITA_CONFIG_DIR}"
fi
if [[ ! -f "${NAVITA_IGNOREFILE}" ]]; then
	printf "%s\n" "/\.git(/.*|)$" > "${NAVITA_IGNOREFILE}"
	printf "Navita: Created %s\n" "${NAVITA_IGNOREFILE}"
fi

# Utility: Update History{{{
__navita::UpdatePathHistory() { 
	while read -r pattern; do
		[[ "${PWD}" =~ ${pattern} ]] && return 0
	done < "${NAVITA_IGNOREFILE}"

	if [[ ! -s "${NAVITA_HISTORYFILE}" ]]; then 
		printf "%s : %d\n" "${PWD}" "$( date +%s )" > "${NAVITA_HISTORYFILE}"
	else
		sed -i "1i ${PWD} : $( date +%s )" "${NAVITA_HISTORYFILE}" 
	fi

	awk -i inplace -F " : " '!seen[$1]++' "${NAVITA_HISTORYFILE}" # remove duplicate paths
}
# }}}

# Utility: Validate Directory{{{
__navita::ValidateDirectory() {
	printf "%s" "$( find "${*}" -maxdepth 0 -exec cd {} \; 2>&1 >/dev/null )"
}
# }}}

# ── Feature: AgeOutHistory ────────────────────────────────────────────{{{
__navita::AgeOutHistory() {

	# if the history file either doesn't exist or have no content, return 0
	[[ ! -s "${NAVITA_HISTORYFILE}" ]] && return 0

	local now_epoch && now_epoch="$( date +%s )"

	if [[ -s "${NAVITA_DATA_DIR}/last-age-check" ]]; then
		local last_check_epoch && last_check_epoch="$( head -1 "${NAVITA_DATA_DIR}/last-age-check" )"
		(( (now_epoch - last_check_epoch)/86400 > NAVITA_MAX_AGE )) || return 0
	fi
	printf "%s\n" "${now_epoch}" > "${NAVITA_DATA_DIR}/last-age-check"

	local max_allowed_age && max_allowed_age="$(( NAVITA_MAX_AGE * 86400 ))"
	local -a line_no_todel
	local line_no=1

	while read -r line; do
		local access_epoch && access_epoch="${line##* : }"
		local line_age && line_age="$(( now_epoch - access_epoch ))"

		(( line_age > max_allowed_age )) && line_no_todel+=( "${line_no}" )
		(( line_no++ ))
	done < "${NAVITA_HISTORYFILE}"

	local colr_grey && colr_grey="\033[1;38;2;122;122;122m"
	local colr_rst && colr_rst='\e[0m'
	
	local index_reduced=0
	local line_no=""
	for line_no in "${line_no_todel[@]}"; do
		local history_line && history_line="$( sed -n "$(( line_no - index_reduced ))p" "${NAVITA_HISTORYFILE}" )"
		local access_epoch && access_epoch="${history_line##* : }"
		local path_age && path_age="$(( now_epoch - access_epoch ))"

		sed -i -e "$(( line_no - index_reduced ))d" "${NAVITA_HISTORYFILE}" && \
			printf "Removed %s ${colr_grey}❰ %s days old${colr_rst}\n" "${history_line%% : *}" "$(( path_age/86400 ))" && \
			(( index_reduced++ ))
	done
}
# }}}

# ── Feature: CleanHistory ───────────────────────────────────────────{{{
__navita::CleanHistory() { 

	# ── Feature: EmptyHistoryFile ─────────────────────────────────────────{{{
	__navita::CleanHistory::EmptyHistoryFile() {
		# NOTE:
		# copy historyfile to tempfile
		# empty the historyfile
		# if success, copy tempfile to historyfile.bak & remove the tempfile
		# if failed, remove the tempfile

		local tempfile && tempfile=$( mktemp )
		$( type -apf cp | head -1 ) "${NAVITA_HISTORYFILE}" "${tempfile}"
		> "${NAVITA_HISTORYFILE}"
		local exitcode="$?"
		if [[ "${exitcode}" -eq 0 ]]; then 
			printf "%s cleaned.\n" "${NAVITA_HISTORYFILE}"
			$( type -apf cp | head -1 ) "${tempfile}" "${NAVITA_HISTORYFILE}.bak"
			printf "Backup created at ${colr_grey}%s.bak${colr_rst}\n" "${NAVITA_HISTORYFILE}"
		fi
		$( type -apf rm | head -1 ) --interactive=never "$tempfile"
		return "$exitcode"
	}
	# }}}

	# ── Feature: RemoveInvalidPaths ───────────────────────────────────────{{{
	__navita::CleanHistory::RemoveInvalidPaths() {
		# NOTE:
		# the line numbers that needs to be deleted from the history file, will be stored in an array
		# using sed, delete those lines in-place

		local -a line_no_todel
		local line_no=1
		local line
		
		while read -r line; do
			line="${line%% : *}"
			local error && error="$( __navita::ValidateDirectory "${line}" )"
			if [[ -n "${error}" ]]; then 
				line_no_todel+=( "${line_no}" )
			fi
			(( line_no++ ))
		done < "${NAVITA_HISTORYFILE}"

		local index_reduced=0
		local line_no
		for line_no in "${line_no_todel[@]}"; do
			local path_to_be_deleted && path_to_be_deleted="$( sed -n "$(( line_no - index_reduced ))p" "${NAVITA_HISTORYFILE}" )" && path_to_be_deleted="${path_to_be_deleted%% : *}"
			local error && error="$( __navita::ValidateDirectory "${path_to_be_deleted}" )" && error=${error#find: }

			sed -i -e "$(( line_no - index_reduced ))d" "${NAVITA_HISTORYFILE}" && \
				printf "Deleted %s ${colr_red}❰ %s${colr_rst}\n" "${path_to_be_deleted}" "${error}" && \
				(( index_reduced++ ))
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
	local check_pwd="${1:-n}"
	local line
	local now_time && now_time="$( date +%s )"
	while read -r line; do
		local _path && _path="${line%% : *}"
		if [[ "${check_pwd}" == "y" ]] && [[ "${_path}" == "${PWD}" ]]; then 
			check_pwd="n"
			continue
		fi
		printf "%s" "${_path}" 

		local access_time && access_time="${line##* : }"
		local seconds_old && seconds_old="$(( now_time - access_time ))"
		local days_old && days_old="$(( seconds_old/86400 ))"
		local hours_old && hours_old="$(( (seconds_old - (days_old * 86400))/3600 ))"
		local minutes_old && minutes_old="$(( (seconds_old - (days_old * 86400) - (hours_old * 3600))/60 ))"

		local path_age=""
		[[ "${days_old}" -gt 0 ]] && path_age="${days_old}d"
		[[ "${hours_old}" -gt 0 ]] && path_age="${path_age}${hours_old}h"
		[[ "${minutes_old}" -gt 0 ]] && path_age="${path_age}${minutes_old}m"

		[[ -n "${path_age}" ]] && printf "${colr_grey} ❰ %s${colr_rst}" "${path_age}"

		local path_error && path_error="$( __navita::ValidateDirectory "${_path}" )"
		[[ -n "${path_error}" ]] && printf "${colr_red}%s${colr_rst}" " ❰ ${path_error#find: }"
		printf "\n"
	done < "${NAVITA_HISTORYFILE}"
}
# }}}

# ── Feature: NavigateHistory ────────────────────────────────────────{{{
__navita::NavigateHistory() {
	local path_returned && path_returned=$( __navita::ViewHistory "y" | fzf --prompt="navita> " --tiebreak=end,index --ansi --nth=1 --with-nth=1,2,3 --delimiter=" ❰ " --exact --select-1 --exit-0 --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {1} && echo && ls -CFaA --color=always {1}" )

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
	local path_returned && path_returned="$( find -L . -mindepth 2 -type d -not -path '*/.git/*' 2> /dev/null | fzf --tiebreak=end,index --select-1 --exit-0 --exact --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {} && echo && ls -CFaA --color=always {}" )"

	case "$?" in
		0) builtin cd -L "${__the_builtin_P_option[@]}" -- "${path_returned}" && __navita::UpdatePathHistory;;
		1) printf "Navita(info): None matched!\n"; return 1;;
		*) return $?;;
	esac
}
# }}}

# ── Feature: CDGeneral ──────────────────────────────────────────────{{{
__navita::CDGeneral() {
	# NOTE: 
	# if string argument provided is either empty or already a legit directory path, then provide the argument to the builtin cd,
	# otherwise search the directories in PWD with the argument,
	# if still no match was found in PWD, call the NavigateHistory feature with the arguments

	if [[ -z "${*}" ]]; then 
		# argument provided by the user is empty
		builtin cd -L "${__the_builtin_P_option[@]}" "${HOME}" && __navita::UpdatePathHistory 
		return $?
	elif [[ -d "${*}" ]]; then
		# argument provided by the user is a valid directory path
		builtin cd -L "${__the_builtin_P_option[@]}" -- "${*}" && __navita::UpdatePathHistory 
		return $?
	fi

	local path_returned && path_returned="$( find -L . -maxdepth 1 -mindepth 1 -type d | fzf --prompt="navita> " --tiebreak=end,index --select-1 --exit-0 --exact --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {} && echo && ls -CFaA --color=always {}" )"

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
			while [[ "${_dir}" != "/" ]]; do
				_dir="$(dirname "${_dir}")"
				printf "%s\n" "${_dir}"
			done
		}

		while read -r line; do
			find -L "${line}" -maxdepth 1 -mindepth 1 -type d -not -path "${PWD}" -print
		done < <(__navita::NavigateParentDirs::GetParentDirs::GetParentNodes) | fzf --prompt="navita> " --tiebreak=end,index --exact --select-1 --exit-0 --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {} && echo && ls -CFaA --color=always {}"
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
			fzf --prompt="navita> " --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${COMP_WORDS[COMP_CWORD]}" --bind=tab:down,btab:up )"

		case "$?" in
			0) COMPREPLY=( "${navita_opts}" );;
			*) 
				local dir_select && dir_select="$( compgen -d -- "${COMP_WORDS[COMP_CWORD]}" | \
					fzf --prompt="navita> " --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${COMP_WORDS[COMP_CWORD]}" --bind=tab:down,btab:up --preview-window=down --border=bold --preview="bash -c 'ls -lashFd --color=always -- \"\${1/#~/${HOME}}\" && echo && ls -CFaA --color=always -- \"\${1/#~/${HOME}}\"' -- {}" )"

				case "$?" in
					0) COMPREPLY=( "${dir_select}" );;
					*) return 0;;
				esac
				;;
		esac
	else
		local dir_select && dir_select="$( compgen -d -- "${COMP_WORDS[COMP_CWORD]}" | \
			fzf --prompt="navita> " --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${COMP_WORDS[COMP_CWORD]}" --bind=tab:down,btab:up --preview-window=down --border=bold --preview="bash -c 'ls -lashFd --color=always -- \"\${1/#~/${HOME}}\" && echo && ls -CFaA --color=always -- \"\${1/#~/${HOME}}\"' -- {}" )"
		
		case "$?" in
			0) COMPREPLY=( "${dir_select}" );;
			*) return 0;;
		esac
	fi
}

complete -F __navita::completions "${NAVITA_COMMAND}"
# }}}

__navita__() {

	local navita_opt
	local -a navita_args
	if [[ "$1" == "-P" ]]; then
		navita_opt="$2"
		navita_args=( "${@:3}" )
		local __the_builtin_P_option && __the_builtin_P_option="-P"
	else
		[[ "${NAVITA_FOLLOW_ACTUAL_PATH}" =~ ^(y|Y)$ ]] && local __the_builtin_P_option && __the_builtin_P_option="-P"
		navita_opt="$1"
		navita_args=( "${@:2}" )
	fi

	local colr_red && colr_red='\033[1;38;2;255;51;51m'
	local colr_green && colr_green="\033[1;38;2;91;255;51m"
	local colr_grey && colr_grey="\033[1;38;2;122;122;122m"
	local colr_blue && colr_blue="\033[1;38;2;0;150;255m"
	local colr_rst && colr_rst='\e[0m'

	case "${navita_opt}" in
		"--") __navita::NavigateHistory "${navita_args[@]}";;
		"--history" | "-H") __navita::ViewHistory;;
		"-") __navita::ToggleLastVisits;;
		"--clean" | "-c") __navita::CleanHistory;;
		"--sub-search" | "-s") __navita::NavigateChildDirs "${navita_args[@]}";;
		"--super-search" | "-S" | "..") 
			if [[ "${navita_opt}" == ".." ]] && [[ -z "${navita_args[0]}" ]]; then
				__navita::CDGeneral ".."
			else
				__navita::NavigateParentDirs "${navita_args[@]}"
			fi
			;;
		"--root" | "-r") printf "Search & traverse in a root directory (to be implemented!)\n";;
		"--version" | "-v") __navita::Version;;
		"--help" | "-h") printf "Print help information (to be implemented!)\n";;
		*) __navita::CDGeneral "${navita_opt}" "${navita_args[@]}";;
	esac
}

# Update the history with the current working directory when opening a new shell
__navita::UpdatePathHistory

# Check for outdated paths when opening a new shell
[[ "${NAVITA_AUTOMATIC_EXPIRE_PATHS}" =~ ^(y|Y) ]] && __navita::AgeOutHistory
