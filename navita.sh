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

# Verify if FZF is installed.
if ! type -ap fzf &> /dev/null; then
	printf "FZF not found! Navita requires FZF!\n" >&2 && return 1
fi

# ── Navita variables ──────────────────────────────────────────────────
export NAVITA_DATA_DIR="${NAVITA_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/navita}"
export NAVITA_HISTORYFILE="${NAVITA_DATA_DIR}/navita-history"
export NAVITA_FOLLOW_ACTUAL_PATH="${NAVITA_FOLLOW_ACTUAL_PATH:-n}"
export NAVITA_COMMAND="${NAVITA_COMMAND:-cd}"
export NAVITA_MAX_AGE="${NAVITA_MAX_AGE:-90}"
export NAVITA_VERSION="Alpha"
export NAVITA_CONFIG_DIR="${NAVITA_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/navita}"
export NAVITA_IGNOREFILE="${NAVITA_CONFIG_DIR}/navita-ignore"
export NAVITA_RELATIVE_PARENT_PATH="${NAVITA_RELATIVE_PARENT_PATH:-y}"
export NAVITA_SHOW_AGE="${NAVITA_SHOW_AGE:-y}"
export NAVITA_DECAY_FACTOR="${NAVITA_DECAY_FACTOR:-6}"

# temporary file for data manipulation for the history file
export __navita_temp_history="${NAVITA_DATA_DIR}/temp-history"

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
	printf "%s\n" "/\.git(/.*|)$" >> "${NAVITA_IGNOREFILE}"
	printf "%s\n" "^${HOME}$" >> "${NAVITA_IGNOREFILE}"
	printf "Navita: Created %s\n" "${NAVITA_IGNOREFILE}"
fi

# Uitility: Get a Path from an entry in history{{{
__navita::GetPathInHistory() {
	# should be passed only a line from the history file
	local line && line="${1}"
	printf "%s\n" "${line%%:*}"
}
# }}}

# Utility: Get Epoch access time of a path/entry in history{{{
__navita::GetAccessEpochInHistory() {
	# can be passed a line from history file
	# or only the path
	# however, it's recommended to pass the complete line for better time performance of this function
	local access_epoch="${1}"
	[[ -d "${1}" ]] && access_epoch="$(grep -m 1 -E "^${1}:" "${NAVITA_HISTORYFILE}")"
	[[ -z "${access_epoch}" ]] && return 1
	
	access_epoch="${access_epoch#*:}"
	access_epoch="${access_epoch%%:*}"
	printf "%s\n" "${access_epoch}"
}
# }}}

# Utility: Get Frequency of a path/entry in history{{{
__navita::GetFreqInHistory() {
	# can be passed a line from history file
	# or only the path
	# however, it's recommended to pass the complete line for better time performance of this function
	local freq="${1}"
	[[ -d "${1}" ]] && freq="$(grep -m 1 -E "^${1}:" "${NAVITA_HISTORYFILE}")"
	[[ -z "${freq}" ]] && return 1

	freq="${freq#*:}"
	freq="${freq#*:}"
	freq="${freq%%:*}"
	printf "%s\n" "${freq}"
}
# }}}

# Utility: Get Age from an Unix Epoch time{{{
__navita::GetAgeFromEpoch() {
	local access_time && access_time="$1"
	local now_time && now_time="${2:-$(date +%s)}"

	local seconds_old && seconds_old="$(( now_time - access_time ))"
	local days_old && days_old="$(( seconds_old/86400 ))"
	local hours_old && hours_old="$(( (seconds_old - (days_old * 86400))/3600 ))"
	local minutes_old && minutes_old="$(( (seconds_old - (days_old * 86400) - (hours_old * 3600))/60 ))"

	local path_age=""
	(( days_old > 0 )) && path_age="${days_old}d"
	(( hours_old > 0 )) && path_age="${path_age}${hours_old}h"
	(( minutes_old > 0 )) && path_age="${path_age}${minutes_old}m"

	printf "%s\n" "${path_age}"
}
# }}}

# Utility: Resolve to Relative path{{{
__navita::GetRelativePath() {
	local _path && _path="$1"
	printf "%s\n" "$(realpath -s --relative-to=. "${_path}")"
}
# }}}

# Utility: Get RankScore for a path{{{
__navita::GetRankScore() {
	local curr_freq && curr_freq="${1?Navita: Frequency of the path is needed for this function!}"
	local curr_access_epoch && curr_access_epoch="${2?Navita: Epoch time of the path is needed for this function!}"
	local max_epoch && max_epoch="${3?Navita: Maximum epoch time from the history is needed for this function!}"

	local max_age && max_age="$(( NAVITA_MAX_AGE * 86400 ))"
	local curr_age && curr_age="$(( max_epoch - curr_access_epoch ))"
	local x && (( x = max_age - curr_age )) && (( x = x < 0 ? 0 : x ))

	printf "%s\n" "$(bc -l <<< "scale=10; l((${curr_freq} * ${x} / ${max_age}) + 1) * e(-1 * ${NAVITA_DECAY_FACTOR} * ${curr_age} / ${max_age})")"
}
# }}}

# Utility: Update History{{{
__navita::UpdatePathHistory() {
	[[ "${OLDPWD}" == "${PWD}" ]] && return 0

	# don't add paths that matches regex from the ignore file
	while read -r pattern; do
		[[ "${PWD}" =~ ${pattern} ]] && return 0
	done < "${NAVITA_IGNOREFILE}"

	local now_epoch && now_epoch="$(date +%s)"

	local curr_path
	local curr_freq
	local curr_epoch
	local pwd_not_found=1

	: > "${__navita_temp_history}"
	while read -r line; do
		curr_path="$(__navita::GetPathInHistory "${line}")"
		curr_freq="$(__navita::GetFreqInHistory "${line}")"
		curr_epoch="$(__navita::GetAccessEpochInHistory "${line}")"

		if [[ ! -d "${curr_path}" ]] || [[ ! -x "${curr_path}" ]]; then
			continue
		elif (( pwd_not_found )) && [[ "${PWD}" == "${curr_path}" ]]; then
			(( curr_freq++ ))
			curr_epoch="${now_epoch}"
			pwd_not_found=0
		fi

		printf "%s:%s:%s:%s\n" "${curr_path}" "${curr_epoch}" "${curr_freq}" "$(__navita::GetRankScore "${curr_freq}" "${curr_epoch}" "${now_epoch}")" >> "${__navita_temp_history}"
	done < "${NAVITA_HISTORYFILE}"

	(( pwd_not_found )) && printf "%s:%s:%s:%s\n" "${PWD}" "${now_epoch}" "1" "$(__navita::GetRankScore "1" "${now_epoch}" "${now_epoch}")" >> "${__navita_temp_history}"
	sort -n -s -b -t':' -k4,4 --reverse --output="${NAVITA_HISTORYFILE}" "${__navita_temp_history}"
}
# }}}

# Utility: Validate Directory{{{
__navita::ValidateDirectory() {
	printf "%s\n" "$(builtin cd -- "${*}" 2>&1 > /dev/null)"
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

		# clear the temporary file
		: > "${__navita_temp_history}"

		$( type -ap cp | head -1 ) "${NAVITA_HISTORYFILE}" "${__navita_temp_history}"
		: > "${NAVITA_HISTORYFILE}"
		local exitcode="$?"
		if (( exitcode == 0 )); then 
			printf "%s cleaned.\n" "${NAVITA_HISTORYFILE}"
			$( type -ap cp | head -1 ) "${__navita_temp_history}" "${NAVITA_HISTORYFILE}.bak"
			printf "Backup created at ${colr_grey}%s.bak${colr_rst}\n" "${NAVITA_HISTORYFILE}"
		fi
		return "$exitcode"
	}
	# }}}

	# ── Feature: RemoveInvalidPaths ───────────────────────────────────────{{{
	__navita::CleanHistory::RemoveInvalidPaths() {
		# clear the temporary file
		: > "${__navita_temp_history}"

		local curr_path
		local path_error

		while read -r line; do
			curr_path="$(__navita::GetPathInHistory "${line}")"
			path_error="$(__navita::ValidateDirectory "${curr_path}")"

			if [[ -n "${path_error}" ]]; then
				printf "Deleted %s ${colr_red}❰ %s${colr_rst}\n" "${curr_path}" "${path_error}"
			else
				printf "%s\n" "${line}" >> "${__navita_temp_history}"
			fi
		done < "${NAVITA_HISTORYFILE}"

		$( type -ap cp | head -1 ) "${__navita_temp_history}" "${NAVITA_HISTORYFILE}" 
	}
	# }}}

	printf "Choose any one:\n"
	printf "1. Remove only invalid paths.\n"
	printf "2. Empty the history.\n"
	printf "\n"
	local user_choice
	read -rp "Choice? (1 or 2): " user_choice
	printf "\n"

	case "${user_choice}" in
		1) __navita::CleanHistory::RemoveInvalidPaths;;
		2) __navita::CleanHistory::EmptyHistoryFile;;
		*) 
			printf "Invalid input!\n" >&2
			return 1
			;;
	esac
}
# }}}

# ── Feature: ViewHistory ────────────────────────────────────────────{{{
__navita::ViewHistory() {
	local line
	local rank
	local age
	local freq
	local score
	local _path
	local path_error
	local now_time && now_time="$(date +%s)"
	while read -r line; do
		rank="${line%%/*}"
		line="/${line#*/}"
		_path="$(__navita::GetPathInHistory "${line}")"
		printf "%s%s" "${rank}" "${_path}" 

		age="$(__navita::GetAgeFromEpoch "$(__navita::GetAccessEpochInHistory "${line}")" "${now_time}")"
		[[ -n "${age}" ]] && printf "${colr_grey} %s${colr_rst}" "❰ ${age}"

		freq="$(__navita::GetFreqInHistory "${line}")"
		[[ -n "${freq}" ]] && printf "${colr_orange} %s${colr_rst}" "❰ ${freq}"

		score="$(printf "%.2f\n" "${line##*:}")"
		[[ -n "${score}" ]] && printf "${colr_blue} %s${colr_rst}" "❰ ${score}"

		path_error="$(__navita::ValidateDirectory "${_path}")"
		[[ -n "${path_error}" ]] && printf "${colr_red} %s${colr_rst}" "❰ ${path_error}"

		printf "\n"
	done < <(case "$1" in
		"--by-time") nl "${NAVITA_HISTORYFILE}" | sort -n -s -b -t':' -k2,2 --reverse;;
		"--by-freq") nl "${NAVITA_HISTORYFILE}" | sort -n -s -b -t':' -k3,3 --reverse;;
		""|"--by-score") nl "${NAVITA_HISTORYFILE}";;
	esac) | less -RF
}
# }}}

# ── Feature: NavigateHistory ────────────────────────────────────────{{{
__navita::NavigateHistory() {
	__navita::NavigateHistory::GetHistory() {
		local _path
		local age
		local path_error
		local now_time && now_time="$(date +%s)"
		local pwd_not_found && pwd_not_found=1
		local line
		while read -r line; do
			_path="$(__navita::GetPathInHistory "${line}")"
			if (( pwd_not_found )) && [[ "${PWD}" == "${_path}" ]]; then
				pwd_not_found=0
				continue
			fi
			printf "%s" "${_path}"

			# show age
			if [[ "${NAVITA_SHOW_AGE}" =~ ^(y|Y)$ ]]; then
				age="$(__navita::GetAgeFromEpoch "$(__navita::GetAccessEpochInHistory "${line}")" "${now_time}")"
				[[ -n "${age}" ]] && printf "${colr_grey} %s${colr_rst}" "❰ ${age}"
			fi

			# show path error
			path_error="$(__navita::ValidateDirectory "${_path}")"
			[[ -n "${path_error}" ]] && printf "${colr_red} %s${colr_rst}" "❰ ${path_error}"

			printf "\n"
		done < "${NAVITA_HISTORYFILE}"
	}

	local path_returned && path_returned="$( __navita::NavigateHistory::GetHistory | fzf +s --prompt="navita> " --tiebreak=end,index --ansi --nth=1 --with-nth=1,2,3 --delimiter=" ❰ " --exact --select-1 --exit-0 --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {1} && echo && ls -CFaA --color=always {1}" )"

	case "$?" in
		0) 
			path_returned="${path_returned%% ❰ *}"
			builtin cd "${__the_builtin_cd_option[@]}" -- "${path_returned}" || return $?
			(&>/dev/null __navita::UpdatePathHistory &)
			;;
		1) printf "Navita(info): None matched!\n" >&2; return 1;;
		*) return $?;;
	esac
}
# }}}

# ── Feature: ToggleLastVisits ──────────────────────────────────────{{{
__navita::ToggleLastVisits() {
	builtin cd "${__the_builtin_cd_option[@]}" - || return $?
	(&>/dev/null __navita::UpdatePathHistory &)
}
# }}}

# ── Feature: NavigateChildDirs ─────────────────────────────────────{{{
__navita::NavigateChildDirs() {
	local path_returned && path_returned="$( find -L . -mindepth 1 -type d -path '*/.git' -prune -o -type d -print 2> /dev/null | fzf --tiebreak=end,index --select-1 --exit-0 --exact --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {} && echo && ls -CFaA --color=always {}" )"

	case "$?" in
		0) 
			builtin cd "${__the_builtin_cd_option[@]}" -- "${path_returned}" || return $?
			(&>/dev/null __navita::UpdatePathHistory &)
			;;
		1) printf "Navita(info): None matched!\n" >&2; return 1;;
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
			if [[ "${NAVITA_RELATIVE_PARENT_PATH}" =~ ^(y|Y)$ ]]; then 
				find -L "$(__navita::GetRelativePath "${line}")" -maxdepth 1 -mindepth 1 -type d -not -path "../${PWD##*/}" -print
			else
				find -L "${line}" -maxdepth 1 -mindepth 1 -type d -not -path "${PWD}" -print
			fi
		done < <(__navita::NavigateParentDirs::GetParentDirs::GetParentNodes) 
	}

	local path_returned && path_returned="$( __navita::NavigateParentDirs::GetParentDirs | fzf +s --prompt="navita> " --tiebreak=end,index --exact --select-1 --exit-0 --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="ls -lashFd --color=always {} && echo && ls -CFaA --color=always {}" )"

	case "$?" in
		0) 
			builtin cd "${__the_builtin_cd_option[@]}" -- "${path_returned}" || return $?
			(&>/dev/null __navita::UpdatePathHistory &)
			;;
		1) printf "Navita(info): None matched!\n" >&2; return 1;;
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
		builtin cd "${__the_builtin_cd_option[@]}" "${HOME}" || return $?
		(&>/dev/null __navita::UpdatePathHistory &) 
		return 0
	elif [[ -d "${*}" ]]; then
		# argument provided by the user is a valid directory path
		builtin cd "${__the_builtin_cd_option[@]}" -- "${*}" || return $?
		(&>/dev/null __navita::UpdatePathHistory &) 
		return 0
	fi

	__navita::CDGeneral::GetPaths() {
		local line
		local _path
		local pwd_not_found=1
		while read -r line; do
			_path="$(__navita::GetPathInHistory "${line}")"
			if (( pwd_not_found )) && [[ "${_path}" == "${PWD}" ]]; then
				pwd_not_found=0
				continue
			fi
			printf "%s\n" "${_path}"
		done < "${NAVITA_HISTORYFILE}"
	}

	# automatically accepts the very first matching highest ranked directory
	local fzf_query && fzf_query="${*}"
	[[ ! "${fzf_query}" =~ .*\$$ ]] && fzf_query="${fzf_query}\$"
	local path_returned && path_returned="$( __navita::CDGeneral::GetPaths | fzf +s --tiebreak=end,index --exact --filter="${fzf_query}" | head -1 )"
	
	if [[ -n "${path_returned}" ]]; then
		builtin cd "${__the_builtin_cd_option[@]}" -- "${path_returned}" || return $?
		(&>/dev/null __navita::UpdatePathHistory &)
	else
		printf "Navita(info): None matched!\n" >&2
		return 1
	fi
}
# }}}

# ── Feature: VersionInfo ─────────────────────────────────────────────{{{
__navita::Version() {
	printf "Navita - %s\n" "${NAVITA_VERSION}"
}
# }}}

[[ -z "${OLDPWD}" ]] && export OLDPWD="${PWD}"

__navita__() {

	local navita_opt
	local -a navita_args
	local __the_builtin_cd_option && __the_builtin_cd_option="-L"
	if [[ "$1" == "-P" ]]; then
		navita_opt="$2"
		navita_args=( "${@:3}" )
		__the_builtin_cd_option="-P"
	else
		[[ "${NAVITA_FOLLOW_ACTUAL_PATH}" =~ ^(y|Y)$ ]] && __the_builtin_cd_option="-P"
		navita_opt="$1"
		navita_args=( "${@:2}" )
	fi

	local colr_red && colr_red='\033[1;38;2;255;51;51m'
	local colr_orange && colr_orange="\033[1;38;2;255;165;0m"
	local colr_grey && colr_grey="\033[1;38;2;122;122;122m"
	local colr_blue && colr_blue="\033[1;38;2;0;150;255m"
	local colr_rst && colr_rst='\e[0m'

	case "${navita_opt}" in
		"--") __navita::NavigateHistory "${navita_args[@]}";;
		"--history" | "-H") __navita::ViewHistory "${navita_args[@]}";;
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

# ── Feature: TabCompletion ────────────────────────────────────────────{{{
if [[ -n "${BASH_VERSION}" ]]; then
	__navita::completions() {
		if (( COMP_CWORD == 1 )) && [[ "${COMP_WORDS[COMP_CWORD]}" =~ ^- ]]; then
			local navita_opts && navita_opts="$(fzf --prompt="navita> " --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${COMP_WORDS[COMP_CWORD]}" --bind=tab:down,btab:up <<< "-"$'\n'"--"$'\n'"-P"$'\n'"-H"$'\n'"--history"$'\n'"-c"$'\n'"--clean"$'\n'"-s"$'\n'"--sub-search"$'\n'"-S"$'\n'"--super-search"$'\n'"-v"$'\n'"--version")"

			case "$?" in
				0) COMPREPLY=( "${navita_opts} " );;
				*) 
					local dir_select && dir_select="$( compgen -d -- "${COMP_WORDS[COMP_CWORD]}" | \
						fzf --prompt="navita> " --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${COMP_WORDS[COMP_CWORD]}" --bind=tab:down,btab:up --preview-window=down --border=bold --preview="bash -c 'ls -lashFd --color=always -- \"\${1/#~/${HOME}}\" && echo && ls -CFaA --color=always -- \"\${1/#~/${HOME}}\"' -- {}" )"

					case "$?" in
						0) COMPREPLY=( "${dir_select}/" );;
						*) return 0;;
					esac
					;;
			esac
		elif (( COMP_CWORD == 2 )) && [[ "${COMP_WORDS[$((COMP_CWORD-1))]}" =~ ^-(H|-history)$ ]]; then
			local navita_opts && navita_opts="$(fzf --prompt="navita> " --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${COMP_WORDS[COMP_CWORD]}" --bind=tab:down,btab:up <<< "--by-time"$'\n'"--by-freq"$'\n'"--by-score")"
			case "$?" in
				0) COMPREPLY=( "${navita_opts} " );;
				*) return 0;;
			esac
		else
			local dir_select && dir_select="$( compgen -d -- "${COMP_WORDS[COMP_CWORD]}" | \
				fzf --prompt="navita> " --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${COMP_WORDS[COMP_CWORD]}" --bind=tab:down,btab:up --preview-window=down --border=bold --preview="bash -c 'ls -lashFd --color=always -- \"\${1/#~/${HOME}}\" && echo && ls -CFaA --color=always -- \"\${1/#~/${HOME}}\"' -- {}" )"

			case "$?" in
				0) COMPREPLY=( "${dir_select}/" );;
				*) return 0;;
			esac
		fi
	}

	complete -o nospace -F __navita::completions "${NAVITA_COMMAND}"
fi
# }}}

