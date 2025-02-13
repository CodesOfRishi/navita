# Copyright 2024-2025 Rishi Kumar
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

declare -a _cmd_type

if [[ -n "${BASH_VERSION}" ]]; then
	_cmd_type=( "type" "-P" )
elif [[ -n "${ZSH_VERSION}" ]]; then
	_cmd_type=( "whence" "-p" )
else
	printf "navita: ERROR: Unknown shell. Navita is exclusive to Bash and Zsh.\n" >&2
	unset _cmd_type
	return 64
fi

declare -A navita_depends
declare navita_all_command_found=1
declare navita_exitcode=0

for _cmd in "fzf" "find" "grep" "sort" "ls" "realpath" "bc" "cp" "less" "nl" "mkdir" "touch" "cat" "flock" "date"; do
	if ! navita_depends["${_cmd}"]="$("${_cmd_type[@]}" "${_cmd}")"; then
		printf "navita: ERROR: %s not found!\n" "${_cmd}" >&2
		navita_all_command_found=0
	fi
done
unset _cmd
unset _cmd_type

if ! (( navita_all_command_found )); then
	unset navita_all_command_found
	unset navita_depends
	unset navita_exitcode
	return 69
else
	unset navita_all_command_found
	if [[ -n "${ZSH_VERSION}" ]] && [[ -z "${EPOCHSECONDS}" ]]; then
		zmodload zsh/datetime || {
			navita_exitcode="$?"
			unset navita_depends
			printf "%s\n" "navita: ERROR: The 'zsh/datetime' module failed to link correctly." >&2
			return "${navita_exitcode}"
		}
	fi
fi

# ── Navita variables ──────────────────────────────────────────────────
export NAVITA_DATA_DIR="${NAVITA_DATA_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/navita}"
export NAVITA_HISTORYFILE="${NAVITA_DATA_DIR}/navita-history"
export NAVITA_FOLLOW_ACTUAL_PATH="${NAVITA_FOLLOW_ACTUAL_PATH:-n}"
export NAVITA_COMMAND="${NAVITA_COMMAND:-cd}"
export NAVITA_HISTORY_LIMIT="${NAVITA_HISTORY_LIMIT:-100}"
export NAVITA_VERSION="v2.3.11"
export NAVITA_CONFIG_DIR="${NAVITA_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/navita}"
export NAVITA_IGNOREFILE="${NAVITA_CONFIG_DIR}/navita-ignore"
export NAVITA_RELATIVE_PARENT_PATH="${NAVITA_RELATIVE_PARENT_PATH:-y}"
export NAVITA_SHOW_AGE="${NAVITA_SHOW_AGE:-y}"
export NAVITA_FZF_EXACT_MATCH="${NAVITA_FZF_EXACT_MATCH:-y}"

# temporary file for data manipulation for the history file
export __navita_temp_history="${NAVITA_DATA_DIR}/.temp-history"
export __navita_last_age_check="${NAVITA_DATA_DIR}/.temp-lastagecheck"
export __navita_lockfile="${NAVITA_DATA_DIR}/.LOCK"

alias "${NAVITA_COMMAND}"="__navita__"

# ── Create data file(s) for Navita ────────────────────────────────────
if [[ ! -d "${NAVITA_DATA_DIR}" ]]; then 
	"${navita_depends["mkdir"]}" -p "${NAVITA_DATA_DIR}" && printf "navita: Created %s\n" "${NAVITA_DATA_DIR}" || return $?
fi
if [[ ! -f "${NAVITA_HISTORYFILE}" ]]; then 
	"${navita_depends["touch"]}" "${NAVITA_HISTORYFILE}" && printf "navita: Created %s\n" "${NAVITA_HISTORYFILE}" || return $?
fi
[[ ! -f "${__navita_last_age_check}" ]] && printf "%s\n" "${EPOCHSECONDS}" >| "${__navita_last_age_check}"

# ── Create configuration file(s) for Navita ───────────────────────────
if [[ ! -d "${NAVITA_CONFIG_DIR}" ]]; then
	"${navita_depends["mkdir"]}" -p "${NAVITA_CONFIG_DIR}" && printf "navita: Created %s\n" "${NAVITA_CONFIG_DIR}" || return $?
fi
if [[ ! -f "${NAVITA_IGNOREFILE}" ]]; then
	"${navita_depends["touch"]}" "${NAVITA_IGNOREFILE}" && printf "navita: Created %s\n" "${NAVITA_IGNOREFILE}" || return $?
	printf "%s\n" "^${HOME}$" >> "${NAVITA_IGNOREFILE}"
	printf "%s\n" "/\.git(/.*|)$" >> "${NAVITA_IGNOREFILE}"
fi

# Utility: Get Epoch access time of a path/entry in history{{{
__navita::GetAccessEpochInHistory() {
	# Should be passed only a line from history file
	local access_epoch
	access_epoch="${1#*:}"
	access_epoch="${access_epoch#*:}"
	printf "%s\n" "${access_epoch%%:*}"
}
# }}}

# Utility: Get Frequency of a path/entry in history{{{
__navita::GetFreqInHistory() {
	# Should be passed only a line from history file
	local freq
	freq="${1#*:}"
	printf "%s\n" "${freq%%:*}"
}
# }}}

# Utility: Get Age from an Unix Epoch time{{{
__navita::GetAgeFromEpoch() {
	local access_time && access_time="$1"

	local seconds_old && seconds_old="$(( EPOCHSECONDS - access_time ))"
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
	"${navita_depends["realpath"]}" -s --relative-to=. "${1}" || {
		navita_exitcode="$?"
		printf "%s\n" "navita: ERROR: Failed to get relative path for %s\n" "${1}" >&2
		return "${navita_exitcode}"
	}
}
# }}}

# Feature: FrecencyRank{{{
#
#                       ⎛                       n                 ⎞
#                       ⎜                      ___                ⎟
#                       ⎜          10          ╲     (-α2(t - Ti))⎟
# FrecencyScore(t) = ln ⎜k + ────────────── +  ╱    e             ⎟
#                       ⎜    1 + α1(t - T0)    ‾‾‾                ⎟
#                       ⎝                     i = 0               ⎠
#
# The above Frecency algorithm was created by @homerours and is used in their [Jumper](https://github.com/homerours/jumper) project, another excellent fast file jumper. 
# @homerours should be credited for the Frecency algorithm.
__navita::UpdatePathHistory() {
	[[ "${OLDPWD}" == "${PWD}" ]] && return 0

	# don't add paths that matches regex from the ignore file
	local pattern
	while read -r pattern; do
		[[ "${PWD}" =~ ${pattern} ]] && return 0
	done < "${NAVITA_IGNOREFILE}"

	# lock history updation preventing race condition
	local FD
	exec {FD}>|"${__navita_lockfile}"
	"${navita_depends["flock"]}" -x -n "${FD}" || {
		navita_exitcode="$?"
		if [[ "${navita_exitcode}" -eq 1 ]]; then
			printf "%s\n" "navita: WARN: History update failed due to a lock contention. Another process may have been modifying the history concurrently." >&2
			return 75
		else
			return "${navita_exitcode}"
		fi
	}

	# history format:-
	# pwd : frequency : access_time : all_visit_score : final_score
	local pwd_not_found=1
	local curr_path curr_freq access_time all_visit_score final_score

	: >| "${__navita_temp_history}"
	while IFS=":" read -r curr_path curr_freq access_time all_visit_score final_score; do
		case "${curr_path}" in
			"${PWD}")
				pwd_not_found=0
				(( curr_freq++ ))
				all_visit_score="$( "${navita_depends["bc"]}" -l <<< "scale=10; ${all_visit_score} * e(-3 * 10^(-7) * (${EPOCHSECONDS} - ${access_time})) + 1" )"
				final_score="$( "${navita_depends["bc"]}" -l <<< "scale=10; l(0.1 + (10/(1 + 2 * 10^(-5) * (${EPOCHSECONDS} - ${access_time}))) + ${all_visit_score})" )"
				printf "%s:%s:%s:%s:%s\n" "${curr_path}" "${curr_freq}" "${EPOCHSECONDS}" "${all_visit_score}" "${final_score}" >> "${__navita_temp_history}"
				;;
			*)
				final_score="$( "${navita_depends["bc"]}" -l <<< "scale=10; l(0.1 + (10/(1 + 2 * 10^(-5) * (${EPOCHSECONDS} - ${access_time}))) + (${all_visit_score} * e(-3 * 10^(-7) * (${EPOCHSECONDS} - ${access_time})) + 1))" )"
				printf "%s:%s:%s:%s:%s\n" "${curr_path}" "${curr_freq}" "${access_time}" "${all_visit_score}" "${final_score}" >> "${__navita_temp_history}"
				;;
		esac
	done < "${NAVITA_HISTORYFILE}"

	(( pwd_not_found )) && printf "%s:1:%s:0:%s\n" "${PWD}" "${EPOCHSECONDS}" "2.4069451083" >> "${__navita_temp_history}"
	"${navita_depends["sort"]}" -n -s -b -t: -k5,5 --reverse --output="${NAVITA_HISTORYFILE}" "${__navita_temp_history}"
	exec {FD}>&-
}
# }}}

# Feature: AgeOutHistory{{{
__navita::AgeOut() {
	# lock history updation preventing race condition
	local FD
	exec {FD}>|"${__navita_lockfile}"
	"${navita_depends["flock"]}" -x -n "${FD}" || {
		navita_exitcode="$?"
		if [[ "${navita_exitcode}" -eq 1 ]]; then
			printf "%s\n" "navita: WARN: History update failed due to a lock contention. Another process may have been modifying the history concurrently." >&2
			return 75
		else
			return "${navita_exitcode}"
		fi
	}

	: >| "${__navita_temp_history}"
	local line _path path_error pattern in_ignorefile=0 line_num=1
	while read -r line; do
		# limit number of paths in the history file to 100
		(( line_num > NAVITA_HISTORY_LIMIT )) && break
		in_ignorefile=0
		path_error=""
		_path="${line%%:*}"

		# remove paths that matches pattern from the ignore file
		while read -r pattern; do
			[[ "${_path}" =~ ${pattern} ]] && in_ignorefile=1 && break
		done < "${NAVITA_IGNOREFILE}"
		(( in_ignorefile )) && continue

		# remove invalid paths
		path_error="$(__navita::ValidateDirectory "${_path}")"
		[[ -n "${path_error}" ]] && continue

		printf "%s\n" "${line}" >> "${__navita_temp_history}"
		(( line_num++ ))
	done < "${NAVITA_HISTORYFILE}"

	"${navita_depends["cp"]}" "${__navita_temp_history}" "${NAVITA_HISTORYFILE}"
	exec {FD}>&-
}
# }}}

# Utility: Validate Directory{{{
__navita::ValidateDirectory() {
	printf "%s\n" "$(builtin cd -- "${*}" 2>&1 >| /dev/null)"
}
# }}}

# ── Feature: CleanHistory ───────────────────────────────────────────{{{
__navita::CleanHistory() { 

	# ── Feature: EmptyHistoryFile ─────────────────────────────────────────{{{
	__navita::CleanHistory::EmptyHistoryFile() {
		# NOTE:
		# copy historyfile to tempfile
		# empty the historyfile
		# if success, copy tempfile to historyfile.bak

		# lock history updation preventing race condition
		local FD
		exec {FD}>|"${__navita_lockfile}"
		"${navita_depends["flock"]}" -x -n "${FD}" || {
			navita_exitcode="$?"
			if [[ "${navita_exitcode}" -eq 1 ]]; then
				printf "%s\n" "navita: WARN: History update failed due to a lock contention. Another process may have been modifying the history concurrently." >&2
				return 75
			else
				return "${navita_exitcode}"
			fi
		}

		local backup_history 
		if backup_history="${NAVITA_HISTORYFILE}-$("${navita_depends["date"]}" +"%Y-%m-%dT%H:%M:%S").bak" && "${navita_depends["cp"]}" "${NAVITA_HISTORYFILE}" "${backup_history}" && : >| "${NAVITA_HISTORYFILE}"; then
			printf "navita: %s cleaned.\n" "${NAVITA_HISTORYFILE}"
			printf "navita: Backup created at ${colr_grey}%s${colr_rst}\n" "${backup_history}"
		else
			navita_exitcode="$?"
			exec {FD}>&-
			return "${navita_exitcode}"
		fi
		exec {FD}>&-
	}
	# }}}

	# ── Feature: RemoveInvalidPaths ───────────────────────────────────────{{{
	__navita::CleanHistory::RemoveInvalidPaths() {
		# lock history updation preventing race condition
		local FD
		exec {FD}>|"${__navita_lockfile}"
		"${navita_depends["flock"]}" -x -n "${FD}" || {
			navita_exitcode="$?"
			if [[ "${navita_exitcode}" -eq 1 ]]; then
				printf "%s\n" "navita: WARN: History update failed due to a lock contention. Another process may have been modifying the history concurrently." >&2
				return 75
			else
				return "${navita_exitcode}"
			fi
		}

		# clear the temporary file
		: >| "${__navita_temp_history}"

		local curr_path path_error line

		while read -r line; do
			curr_path="${line%%:*}"
			path_error="$(__navita::ValidateDirectory "${curr_path}")"

			if [[ -n "${path_error}" ]]; then
				printf "navita: Deleted %s ${colr_red}❰ %s${colr_rst}\n" "${curr_path}" "${path_error}"
			else
				printf "%s\n" "${line}" >> "${__navita_temp_history}"
			fi
		done < "${NAVITA_HISTORYFILE}"

		"${navita_depends["cp"]}" "${__navita_temp_history}" "${NAVITA_HISTORYFILE}" 
		exec {FD}>&-
	}
	# }}}
	
	# ── Feature: RemoveIgnoredPaths ───────────────────────────────────────{{{
	__navita::CleanHistory::IgnoredPaths() {
		# lock history updation preventing race condition
		local FD
		exec {FD}>|"${__navita_lockfile}"
		"${navita_depends["flock"]}" -x -n "${FD}" || {
			navita_exitcode="$?"
			if [[ "${navita_exitcode}" -eq 1 ]]; then
				printf "%s\n" "navita: WARN: History update failed due to a lock contention. Another process may have been modifying the history concurrently." >&2
				return 75
			else
				return "${navita_exitcode}"
			fi
		}

		: >| "${__navita_temp_history}"
		local line _path pattern none_matched
		while read -r line; do
			none_matched=1
			_path="${line%%:*}"
			while read -r pattern; do
				if [[ "${_path}" =~ ${pattern} ]]; then
					printf "navita: Deleted ${colr_red}%s${colr_rst} (matched ${colr_brown}%s${colr_rst})\n" "${_path}" "${pattern}"
					none_matched=0
					break
				fi
			done < "${NAVITA_IGNOREFILE}"
			(( none_matched )) && printf "%s\n" "${line}" >> "${__navita_temp_history}"
		done < "${NAVITA_HISTORYFILE}"
		
		"${navita_depends["cp"]}" "${__navita_temp_history}" "${NAVITA_HISTORYFILE}"
		exec {FD}>&-
	}
	# }}}

	# ── Feature: RemoveCustomPaths ────────────────────────────────────────{{{
	__navita::CleanHistory::Custom() {
		# lock history updation preventing race condition
		local FD
		exec {FD}>|"${__navita_lockfile}"
		"${navita_depends["flock"]}" -x -n "${FD}" || {
			navita_exitcode="$?"
			if [[ "${navita_exitcode}" -eq 1 ]]; then
				printf "%s\n" "navita: WARN: History update failed due to a lock contention. Another process may have been modifying the history concurrently." >&2
				return 75
			else
				return "${navita_exitcode}"
			fi
		}

		__navita::CleanHistory::Custom::GetPaths() {
			local rank _path freq epoch visit_score final_score
			while IFS=":" read -r rank _path freq epoch visit_score final_score; do
				printf "%s ${colr_grey}:${colr_rst} ${colr_white}%s${colr_rst} ${colr_grey}:${colr_rst} ${colr_brown}%s${colr_rst} ${colr_grey}:${colr_rst} ${colr_grey}%s${colr_rst}\n" "$rank" "$_path" "$freq" "$(__navita::GetAgeFromEpoch "$epoch")"
			done < <("${navita_depends["nl"]}" -s ":" "${NAVITA_HISTORYFILE}") | "${navita_depends["fzf"]}" --header='Use Tab or Shift-Tab to (de)select paths' --ansi --prompt='❯ ' --info='inline: ❮ ' --info-command='echo -e "\x1b[33;1m${FZF_INFO%%/*}\x1b[m/${FZF_INFO##*/} Choose paths to remove « Navita"' --layout='reverse' --scheme='path' --tiebreak='end,index' --delimiter=" : " --nth=2 --with-nth=1,2,3,4 --multi | "${navita_depends["sort"]}" -b -n -t ':' --key=1,1
		}

		local -a paths_to_remove
		IFS=$'\n' paths_to_remove=( $(__navita::CleanHistory::Custom::GetPaths) ) || {
			navita_exitcode="$?"
			printf "%s\n" "navita: ERROR: Something went wrong during assignment of the selected paths to an array!" >&2
			exec {FD}>&-
			return "${navita_exitcode}"
		}
		[[ "${#paths_to_remove[@]}" -eq 0 ]] && printf "%s\n" "navita: No paths were removed from history." >&2 && {
			exec {FD}>&-
			return 65
		}

		local line rank _path freq duration i=0
		[[ -n "${ZSH_VERSION}" ]] && i=1
		while (( 1 )); do
			if [[ -n "${BASH_VERSION}" ]]; then 
				(( i >= ${#paths_to_remove[@]} )) && break
			elif [[ -n "${ZSH_VERSION}" ]]; then
				(( i > ${#paths_to_remove[@]} )) && break
			fi

			line="${paths_to_remove[i]}"
			rank="${line%% : *}" && line="${line#* : }"
			_path="${line%% : *}" && line="${line#* : }"
			freq="${line%% : *}" && line="${line#* : }"
			duration="${line%%: *}"
			printf "%s ${colr_grey}:${colr_rst} ${colr_white}%s${colr_rst} ${colr_grey}:${colr_rst} ${colr_brown}%s${colr_rst} ${colr_grey}:${colr_rst} ${colr_grey}%s${colr_rst}\n" "$rank" "$_path" "$freq" "$duration"
			(( i++ ))
		done
		unset i rank _path freq duration line

		local user_choice
		printf "\n"
		if [[ -n "${BASH_VERSION}" ]]; then 
			read -rp "Remove the above path(s) from history? [Y/n]: " user_choice
		elif [[ -n "${ZSH_VERSION}" ]]; then
			read -r "user_choice?Remove the above path(s) from history? [Y/n]: " 
		fi

		case "${user_choice}" in
			Y|y) 
				local curr_line curr_rank=1 rank_to_remove i=0
				[[ -n "${ZSH_VERSION}" ]] && i=1
				entry_to_remove="${paths_to_remove[i]}"
				rank_to_remove="${entry_to_remove%% : *}"
				rank_to_remove="${rank_to_remove##* }"
				rank_to_remove="${rank_to_remove%% *}"

				: >| "${__navita_temp_history}"
				while read -r curr_line; do
					if [[ -n "${ZSH_VERSION}" ]] && (( i <= ${#paths_to_remove[@]} )) && [[ "${curr_rank}" == "${rank_to_remove}" ]]; then
						(( i++ ))
						entry_to_remove="${paths_to_remove[i]}"
						rank_to_remove="${entry_to_remove%% : *}"
						rank_to_remove="${rank_to_remove##* }"
						rank_to_remove="${rank_to_remove%% *}"
					elif [[ -n "${BASH_VERSION}" ]] && (( i < ${#paths_to_remove[@]} )) && [[ "${curr_rank}" == "${rank_to_remove}" ]]; then
						(( i++ ))
						entry_to_remove="${paths_to_remove[i]}"
						rank_to_remove="${entry_to_remove%% : *}"
						rank_to_remove="${rank_to_remove##* }"
						rank_to_remove="${rank_to_remove%% *}"
					else
						printf "%s\n" "${curr_line}" >> "${__navita_temp_history}"
					fi
					(( curr_rank++ ))
				done < "${NAVITA_HISTORYFILE}"
				"${navita_depends["cp"]}" "${__navita_temp_history}" "${NAVITA_HISTORYFILE}"
				;;
			*) printf "%s\n" "navita: No paths were removed from history.";;
		esac
		exec {FD}>&-
	}
	# }}}

	local colr_white && colr_white='\033[1;38;2;255;255;255m'
	local colr_brown && colr_brown='\033[1;38;2;229;152;102m'
	local colr_red && colr_red='\033[1;38;2;255;51;51m'
	local colr_grey && colr_grey="\033[1;38;2;122;122;122m"

	case "${1}" in
		"--invalid-paths") __navita::CleanHistory::RemoveInvalidPaths;;
		"--ignored-paths") __navita::CleanHistory::IgnoredPaths;;
		"--custom-paths") __navita::CleanHistory::Custom;;
		"--full-history") __navita::CleanHistory::EmptyHistoryFile;;
		"")
			printf "Choose any one:\n"
			printf "1. Remove only invalid paths.\n"
			printf "2. Remove ignored paths.\n"
			printf "3. Remove custom paths.\n"
			printf "4. Clear the full history.\n"
			printf "x to abort.\n"
			printf "\n"
			local user_choice
			if [[ -n "${BASH_VERSION}" ]]; then 
				read -rp "Choice?: " user_choice
			elif [[ -n "${ZSH_VERSION}" ]]; then
				read -r "user_choice?Choice?: " 
			fi
			printf "\n"

			case "${user_choice}" in
				1) __navita::CleanHistory::RemoveInvalidPaths;;
				2) __navita::CleanHistory::IgnoredPaths;;
				3) __navita::CleanHistory::Custom;;
				4) __navita::CleanHistory::EmptyHistoryFile;;
				"x") printf "navita: Aborted.\n";;
				*) 
					printf "navita: ERROR: Invalid input!\n" >&2
					return 65
					;;
			esac
			;;
		*) 
			printf "navita: ERROR: Invalid options/arguments!\n" >&2
			return 64
			;;
	esac
}
# }}}

# ── Feature: ViewHistory ────────────────────────────────────────────{{{
__navita::ViewHistory() {
	case "$1" in
		""|"--by-time"|"--by-freq"|"--by-score") :;;
		*) printf "navita: ERROR: Invalid options/arguments!\n" >&2; return 64;;
	esac

	local colr_red && colr_red='\033[1;38;2;255;51;51m'
	local colr_green && colr_green='\033[1;38;2;170;255;0m'
	local colr_orange && colr_orange="\033[1;38;2;255;165;0m"
	local colr_brown && colr_brown='\033[1;38;2;229;152;102m'
	local colr_grey && colr_grey="\033[1;38;2;122;122;122m"
	local colr_blue && colr_blue="\033[1;38;2;0;150;255m"

	local line rank age freq score _path path_error
	while read -r line; do
		rank="${line%%/*}"
		line="/${line#*/}"
		_path="${line%%:*}"

		case "${_path}" in
			"${PWD}") printf "%s${colr_green}PWD ❱${colr_rst} %s" "${rank}" "${_path}";;
			"${OLDPWD}") printf "%s${colr_brown}LWD ❱${colr_rst} %s" "${rank}" "${_path}";;
			*) printf "%s%s" "${rank}" "${_path}";;
		esac

		age="$(__navita::GetAgeFromEpoch "$(__navita::GetAccessEpochInHistory "${line}")")"
		[[ -n "${age}" ]] && printf "${colr_grey} %s${colr_rst}" "❰ ${age}"

		freq="$(__navita::GetFreqInHistory "${line}")"
		[[ -n "${freq}" ]] && printf "${colr_orange} %s${colr_rst}" "❰ ${freq}"

		score="${line##*:}"
		[[ -n "${score}" ]] && printf "${colr_blue} %s${colr_rst}" "❰ ${score}"

		path_error="$(__navita::ValidateDirectory "${_path}")"
		[[ -n "${path_error}" ]] && printf "${colr_red} %s${colr_rst}" "❰ ${path_error}"

		printf "\n"
	done < <(case "$1" in
		"--by-time") "${navita_depends["nl"]}" "${NAVITA_HISTORYFILE}" | "${navita_depends["sort"]}" -n -s -b -t':' -k3,3 --reverse;;
		"--by-freq") "${navita_depends["nl"]}" "${NAVITA_HISTORYFILE}" | "${navita_depends["sort"]}" -n -s -b -t':' -k2,2 --reverse;;
		""|"--by-score") "${navita_depends["nl"]}" "${NAVITA_HISTORYFILE}";;
	esac) | "${navita_depends["less"]}" -RF
}
# }}}

# ── Feature: NavigateHistory ────────────────────────────────────────{{{
__navita::NavigateHistory() {
	__navita::NavigateHistory::GetHistory() {
		local colr_red && colr_red='\033[1;38;2;255;51;51m'
		local colr_grey && colr_grey="\033[1;38;2;122;122;122m"

		local _path path_error age line pwd_not_found=1
		while read -r line; do
			_path="${line%%:*}"
			if (( pwd_not_found )) && [[ "${PWD}" == "${_path}" ]]; then
				pwd_not_found=0
				continue
			fi
			printf "%s" "${_path}"

			# show age
			if [[ "${NAVITA_SHOW_AGE}" =~ ^(y|Y)$ ]]; then
				age="$(__navita::GetAgeFromEpoch "$(__navita::GetAccessEpochInHistory "${line}")")"
				[[ -n "${age}" ]] && printf "${colr_grey} %s${colr_rst}" "❰ ${age}"
			fi

			# show path error
			path_error="$(__navita::ValidateDirectory "${_path}")"
			[[ -n "${path_error}" ]] && printf "${colr_red} %s${colr_rst}" "❰ ${path_error}"

			printf "\n"
		done < "${NAVITA_HISTORYFILE}"
	}

	local -a fzf_conditional_options
	[[ "${NAVITA_FZF_EXACT_MATCH}" =~ ^(y|Y)$ ]] && fzf_conditional_options+=( "--exact" )

	local path_returned && path_returned="$( __navita::NavigateHistory::GetHistory | "${navita_depends["fzf"]}" --prompt='❯ ' --info='inline: ❮ ' --info-command='echo -e "\x1b[33;1m${FZF_INFO%%/*}\x1b[m/${FZF_INFO##*/} History « Navita"' --height "50%" --ansi --nth=1 --with-nth='1,2,3' --delimiter=' ❰ ' "${fzf_conditional_options[@]}" --scheme='path' --tiebreak='end,index' --exit-0 --query="${*}" --layout='reverse' --preview-window='down' --border='bold' --preview="${navita_depends["ls"]} -CFaA --color=always {1}" )"

	case "$?" in
		0) 
			path_returned="${path_returned%% ❰ *}"
			builtin cd "${__the_builtin_cd_option[@]}" -- "${path_returned}" || return $?
			(__navita::UpdatePathHistory &)
			;;
		1) printf "navita: None matched!\n" >&2; return 1;;
		*) return $?;;
	esac
}
# }}}

# ── Feature: ToggleLastVisits ──────────────────────────────────────{{{
__navita::ToggleLastVisits() {
	builtin cd "${__the_builtin_cd_option[@]}" - || return $?
	(__navita::UpdatePathHistory &)
}
# }}}

# ── Feature: NavigateChildDir ─────────────────────────────────────{{{
__navita::NavigateChildDirs() {
	local -a fzf_conditional_options
	[[ -n "${*}" ]] && fzf_conditional_options+=( --select-1 )
	[[ "${NAVITA_FZF_EXACT_MATCH}" =~ ^(y|Y)$ ]] && fzf_conditional_options+=( --exact )

	local path_returned && path_returned="$( "${navita_depends["find"]}" -L . -mindepth 1 -type d -path '*/.git' -prune -o -type d -print 2>| /dev/null | "${navita_depends["fzf"]}" --prompt='❯ ' --info='inline: ❮ ' --info-command='echo -e "\x1b[33;1m${FZF_INFO%%/*}\x1b[m/${FZF_INFO##*/} Sub-directories « Navita"' --height "50%" "${fzf_conditional_options[@]}" --scheme='path' --tiebreak='end,index' --exit-0 --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="${navita_depends["ls"]} -CFaA --color=always {}" )"

	case "$?" in
		0) 
			builtin cd "${__the_builtin_cd_option[@]}" -- "${path_returned}" || return $?
			(__navita::UpdatePathHistory &)
			;;
		1) printf "navita: None matched!\n" >&2; return 1;;
		*) return $?;;
	esac
}
# }}}

# ── Feature: NavigateParentDir ───────────────────────────────────────{{{
__navita::NavigateParentDirs() {
	__navita::NavigateParentDirs::GetParentDirs() {
		__navita::NavigateParentDirs::GetParentDirs::GetParentNodes() {
			local _dir && _dir="${PWD}"
			while [[ "${#_dir}" -gt 1 ]] && [[ "${_dir: -1}" == "/" ]]; do
				_dir="${_dir:0: -1}"
			done

			until [[ -z "${_dir}" ]] || [[ "${_dir}" == "/" ]]; do
				_dir="${_dir%/*}"
				while [[ "${#_dir}" -gt 1 ]] && [[ "${_dir: -1}" == "/" ]]; do
					_dir="${_dir:0: -1}"
				done
				[[ -n "${_dir}" ]] && printf "%s\n" "${_dir}"
			done
			[[ -z "${_dir}" ]] && printf "/\n"
		}

		local line
		while read -r line; do
			if [[ "${NAVITA_RELATIVE_PARENT_PATH}" =~ ^(y|Y)$ ]]; then 
				"${navita_depends["find"]}" -L "$(__navita::GetRelativePath "${line}")" -maxdepth 1 -mindepth 1 -type d -not -path "../${PWD##*/}" -print
			else
				"${navita_depends["find"]}" -L "${line}" -maxdepth 1 -mindepth 1 -type d -not -path "${PWD}" -print
			fi
		done < <(__navita::NavigateParentDirs::GetParentDirs::GetParentNodes) 
	}

	local -a fzf_conditional_options
	[[ -n "${*}" ]] && fzf_conditional_options+=( --select-1 )
	[[ "${NAVITA_FZF_EXACT_MATCH}" =~ ^(y|Y)$ ]] && fzf_conditional_options+=( --exact )

	local path_returned && path_returned="$( __navita::NavigateParentDirs::GetParentDirs | "${navita_depends["fzf"]}" --prompt='❯ ' --info='inline: ❮ ' --info-command='echo -e "\x1b[33;1m${FZF_INFO%%/*}\x1b[m/${FZF_INFO##*/} Parent-directories « Navita"' --height "50%" "${fzf_conditional_options[@]}" --scheme='path' --tiebreak='end,index' --exit-0 --layout=reverse --preview-window=down --border=bold --query="${*}" --preview="${navita_depends["ls"]} -CFaA --color=always {}" )"

	case "$?" in
		0) 
			builtin cd "${__the_builtin_cd_option[@]}" -- "${path_returned}" || return $?
			(__navita::UpdatePathHistory &)
			;;
		1) printf "navita: None matched!\n" >&2; return 1;;
		*) return $?;;
	esac
}
# }}}

# ── Feature: CDGeneral ──────────────────────────────────────────────{{{
__navita::CDGeneral() {

	if [[ -z "${*}" ]]; then 
		# argument provided by the user is empty
		builtin cd "${__the_builtin_cd_option[@]}" "${HOME}" || return $?
		(__navita::UpdatePathHistory &)
		return $?
	elif [[ -d "${*}" ]]; then
		# argument provided by the user is a valid directory path
		builtin cd "${__the_builtin_cd_option[@]}" -- "${*}" || return $?
		(__navita::UpdatePathHistory &)
		return $?
	fi

	__navita::CDGeneral::GetPaths() {
		local line _path pwd_not_found=1
		while read -r line; do
			_path="${line%%:*}"
			if (( pwd_not_found )) && [[ "${_path}" == "${PWD}" ]]; then
				pwd_not_found=0
				continue
			fi
			printf "%s\n" "${_path}"
		done < "${NAVITA_HISTORYFILE}"
	}

	local srch_inc=""
	local srch_exc=""
	local end_of_str_anchor_found=0
	local last_search_type=0
	local pattern

	for pattern in "${@}"; do
		pattern="${pattern//./\\.}"
		
		(( end_of_str_anchor_found == 0 )) && [[ "${pattern: -1}" == "$" ]] && end_of_str_anchor_found=1
		if [[ "${pattern:0:1}" == "!" ]]; then 
			srch_exc="${srch_exc}${pattern:1}|" 
			last_search_type=2
		else
			srch_inc="${srch_inc}(?=.*${pattern})"
			last_search_type=1
		fi
	done
	unset pattern

	[[ "${srch_exc: -1}" == "|" ]] && srch_exc="${srch_exc:0: -1}"
	if (( end_of_str_anchor_found == 0 )); then
		case "${last_search_type}" in
			"1")
				# inclusion search term
				srch_inc="${srch_inc:0:-1}\$)"
				;;
			"2")
				# exclusion search term
				srch_exc="${srch_exc}\$"
				;;
		esac
	fi

	local path_returned
	if [[ -n "${srch_exc}" ]] && [[ -n "${srch_inc}" ]]; then
		path_returned="$(__navita::CDGeneral::GetPaths | ${navita_depends["grep"]} -vP "${srch_exc}" | ${navita_depends["grep"]} -m 1 -P "${srch_inc}")"
	elif [[ -z "${srch_exc}" ]] && [[ -n "${srch_inc}" ]]; then
		path_returned="$(__navita::CDGeneral::GetPaths | ${navita_depends["grep"]} -m 1 -P "${srch_inc}")"
	elif [[ -n "${srch_exc}" ]] && [[ -z "${srch_inc}" ]]; then
		path_returned="$(__navita::CDGeneral::GetPaths | ${navita_depends["grep"]} -m 1 -vP "${srch_exc}")"
	fi

	case "$?" in
		0) 
			builtin cd "${__the_builtin_cd_option[@]}" -- "${path_returned}" || return $?
			(__navita::UpdatePathHistory &)
			;;
		1) printf "navita: None matched!\n" >&2; return 1;;
		*) return "$?";;
	esac
}
# }}}

# ── Feature: VersionInfo ─────────────────────────────────────────────{{{
__navita::Version() {
	printf "Navita - %s\n" "${NAVITA_VERSION}"
}
# }}}

# ── Feature: ViewHelp ────────────────────────────────────────────────{{{
__navita::ViewHelp() {
"${navita_depends["cat"]}" << EOF
Navita is a Bash/Zsh utility for rapid directory traversal, employing fuzzy matching, history tracking, and path validation for efficient file system navigation.

Usage:
	cd [-P] [PCRE_EXPRESSION... | DIR]
	   [-P] -
	   [-P] -- [STRING...]
	   [-P] (-s | --sub-search) [STRING...]
	   [-P] (-S | --super-search | ..) [STRING...]
	   (-c | --clean) [--full-history | --ignored-paths | --custom-paths | --invalid-paths]
	   (-H | --history) [--by-freq | --by-score | --by-time]
	   (-v | --version)
	   (-h | --help)

Main Options:
	-                       Traverse to the previous working directory
	--                      Search and traverse from history
	-P                      Resolve symbolic links and traverse to the actual directory
	--clean,         -c     Choose what to clear from history or clear all
	--history,       -H     View Navita's history of directory visits
	--sub-search,    -s     Recursively search and traverse sub-directories
	--super-search,  -S     Search and traverse 1-level below the parent directories
	--version,       -v     Navita's version information
	--help,          -h     Show help (this) message

Sub-options for -H/--history:
	--by-freq      Sort history by frequency
	--by-score     Sort history by score
	--by-time      Sort history by access time

Sub-options for -c/--clean:
	--full-history      Clear the full history
	--ignored-paths     Remove ignored paths
	--invalid-paths     Remove invalid paths
	--custom-paths      Remove custom paths

Configurable Environment Variables:
	NAVITA_DATA_DIR                 Directory location for Navita's data files
	NAVITA_CONFIG_DIR               Directory location for Navita's configuration files
	NAVITA_COMMAND                  Name of the command to use Navita
	NAVITA_FOLLOW_ACTUAL_PATH       Instruct Navita to follow symbolic links or not before changing the directory
	NAVITA_RELATIVE_PARENT_PATH     Instruct Navita to show resolved parent paths relative to the current directory or not
	NAVITA_SHOW_AGE                 Instruct Navita to show age annotation next to paths during history search or not
	NAVITA_FZF_EXACT_MATCH          Instruct Navita to use exact or fuzzy match in FZF search or not
	NAVITA_HISTORY_LIMITS           Maximum number of directory paths Navita should remember

Non-configurable Environment Variables:
	NAVITA_VERSION         Navita's version information
	NAVITA_IGNOREFILE      The file with regex patterns to ignore paths from history
	NAVITA_HISTORYFILE     The file with Navita's directory history and metadata like frequency, access time, and score

Exit Status:
	0      Success.
	64     The command was used incorrectly, e.g., with an invalid number of arguments, an unrecognized flag, or a malformed parameter.
	65     The input data was malformed or invalid.
	69     A service is currently unavailable. This could be caused by missing dependencies or other unforeseen issues.
	75     A temporary failure has occurred. The request can be retried at a later time.
	Exit codes other than those explicitly handled may be attributed to external programs.

Project Author: Rishi Kumar <contact.rishikmr@gmail.com>
Project URL: https://github.com/CodesOfRishi/navita 

EOF
}
# }}}

# check directory paths' aging once every 24 hours
if [[ "$(( EPOCHSECONDS - "$(${navita_depends["cat"]} "${__navita_last_age_check}")" ))" -gt 86400 ]]; then
	printf "%s\n" "${EPOCHSECONDS}" >| "${__navita_last_age_check}"
	__navita::AgeOut
fi

[[ -z "${OLDPWD}" ]] && OLDPWD="${PWD}"

__navita__() {
	local __the_builtin_cd_option && __the_builtin_cd_option="-L"
	if [[ "$1" == "-P" ]]; then
		shift
		__the_builtin_cd_option="-P"
	elif [[ "${NAVITA_FOLLOW_ACTUAL_PATH}" =~ ^(y|Y)$ ]]; then
		__the_builtin_cd_option="-P"
	fi

	local colr_rst && colr_rst='\e[0m'

	case "$1" in
		"--") __navita::NavigateHistory "${@:2}";;
		"--history" | "-H") __navita::ViewHistory "${@:2}";;
		"-") __navita::ToggleLastVisits;;
		"--clean" | "-c") __navita::CleanHistory "${@:2}";;
		"--sub-search" | "-s") __navita::NavigateChildDirs "${@:2}";;
		"--super-search" | "-S") __navita::NavigateParentDirs "${@:2}";;
		"..")
			if [[ "$#" -eq 1 ]]; then
				__navita::CDGeneral ".."
			else
				__navita::NavigateParentDirs "${@:2}"
			fi
			;;
		"--help" | "-h") __navita::ViewHelp;;
		"--version" | "-v") __navita::Version;;
		*) __navita::CDGeneral "${@}";;
	esac
}

# ── Feature: TabCompletion ────────────────────────────────────────────{{{
if [[ -n "${BASH_VERSION}" ]]; then
	__navita::Completions() {
		# To redraw line after fzf closes (printf '\e[5n') 
		# This is useful when the terminal is altered by FZF, and the command line gets visually corrupted or misaligned
		bind '"\e[0n": redraw-current-line' 2>| /dev/null

		local ignore_case_completion_default && ignore_case_completion_default="$(bind -v | ${navita_depends["grep"]} -m 1 -F 'set completion-ignore-case')" && ignore_case_completion_default="${ignore_case_completion_default##* }"
		bind "set completion-ignore-case on" 

		# Get Highest-ranked directory for completion{{{
		__navita::Completions::GetHighestRankDirectory() {
			# The function should be identical to the highest-ranked directory traversal part of the __navita::CDGeneral() function
			__navita::CDGeneral::GetPaths() {
				local line _path pwd_not_found=1
				while read -r line; do
					_path="${line%%:*}"
					if (( pwd_not_found )) && [[ "${_path}" == "${PWD}" ]]; then
						pwd_not_found=0
						continue
					fi
					printf "%s\n" "${_path}"
				done < "${NAVITA_HISTORYFILE}"
			}

			local srch_inc=""
			local srch_exc=""
			local end_of_str_anchor_found=0
			local last_search_type=0
			local pattern

			for pattern in "${@}"; do
				pattern="${pattern//./\\.}"
				# interpret special characters
				eval "pattern=$pattern"

				(( end_of_str_anchor_found == 0 )) && [[ "${pattern: -1}" == "$" ]] && end_of_str_anchor_found=1
				if [[ "${pattern:0:1}" == "!" ]]; then 
					srch_exc="${srch_exc}${pattern:1}|" 
					last_search_type=2
				else
					srch_inc="${srch_inc}(?=.*${pattern})"
					last_search_type=1
				fi
			done
			unset pattern

			[[ "${srch_exc: -1}" == "|" ]] && srch_exc="${srch_exc:0: -1}"
			if (( end_of_str_anchor_found == 0 )); then
				case "${last_search_type}" in
					"1")
						# inclusion search term
						srch_inc="${srch_inc:0:-1}\$)"
						;;
					"2")
						# exclusion search term
						srch_exc="${srch_exc}\$"
						;;
				esac
			fi

			if [[ -n "${srch_exc}" ]] && [[ -n "${srch_inc}" ]]; then
				__navita::CDGeneral::GetPaths | ${navita_depends["grep"]} -vP "${srch_exc}" | ${navita_depends["grep"]} -m 1 -P "${srch_inc}"
			elif [[ -z "${srch_exc}" ]] && [[ -n "${srch_inc}" ]]; then
				__navita::CDGeneral::GetPaths | ${navita_depends["grep"]} -m 1 -P "${srch_inc}"
			elif [[ -n "${srch_exc}" ]] && [[ -z "${srch_inc}" ]]; then
				__navita::CDGeneral::GetPaths | ${navita_depends["grep"]} -m 1 -vP "${srch_exc}"
			fi
		}
		# }}}

		# Directory completion{{{
		__navita::Completions::CompleteDirectory() {
			local dir_select
			if dir_select="$( compgen -o bashdefault -d -- "${curr_word}" | \
				"${navita_depends["fzf"]}" --prompt='❯ ' --info='inline: ❮ ' --info-command='echo -e "\x1b[33;1m${FZF_INFO%%/*}\x1b[m/${FZF_INFO##*/} Directory completion « Navita"' --height "40%" --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${COMP_WORDS[COMP_CWORD]}" --bind=tab:down,btab:up --cycle --preview-window=down --border=bold --preview="command bash -c '${navita_depends["ls"]} -CFaA --color=always -- \"\${1/#~/${HOME}}\"' -- {}" )"; then
				dir_select="${dir_select}/"
			fi

			COMPREPLY=( "${dir_select}" )
			printf '\e[5n'
		}
		# }}}

		# Navita's Main-options{{{
		__navita::Completions::GetMainOptions() {
			local colr_grey && colr_grey="\033[1;38;2;122;122;122m"
			local colr_rst && colr_rst='\e[0m'
			
			printf "%s                   ${colr_grey}❰ Traverse to the previous working directory${colr_rst}\n" "-"
			printf "%s                  ${colr_grey}❰ Search and traverse from history${colr_rst}\n" "--"
			printf "%s                  ${colr_grey}❰ Resolve symbolic links and traverse to the physical directory${colr_rst}\n" "-P"
			printf "%s                  ${colr_grey}❰ View Navita's history of directory visits${colr_rst}\n" "-H"
			printf "%s           ${colr_grey}❰ View Navita's history of directory visits${colr_rst}\n" "--history"
			printf "%s                  ${colr_grey}❰ Choose what to clear from history or clear all${colr_rst}\n" "-c"
			printf "%s             ${colr_grey}❰ Choose what to clear from history or clear all${colr_rst}\n" "--clean"
			printf "%s                  ${colr_grey}❰ Recursively search and traverse sub-directories${colr_rst}\n" "-s"
			printf "%s        ${colr_grey}❰ Recursively search and traverse sub-directories${colr_rst}\n" "--sub-search"
			printf "%s                  ${colr_grey}❰ Search and traverse 1-level below the parent directories${colr_rst}\n" "-S"
			printf "%s      ${colr_grey}❰ Search and traverse 1-level below the parent directories${colr_rst}\n" "--super-search"
			printf "%s                  ${colr_grey}❰ View help message${colr_rst}\n" "-h"
			printf "%s              ${colr_grey}❰ View help message${colr_rst}\n" "--help"
			printf "%s                  ${colr_grey}❰ Navita's version information${colr_rst}\n" "-v"
			printf "%s           ${colr_grey}❰ Navita's version information${colr_rst}\n" "--version"
		}
		# }}}

		# Navita's History Sub-options{{{
		__navita::Completions::GetHistorySubOptions() {
			local colr_grey && colr_grey="\033[1;38;2;122;122;122m"
			local colr_rst && colr_rst='\e[0m'

			printf "%s       ${colr_grey}❰ Sort history by access time${colr_rst}\n" "--by-time"
			printf "%s       ${colr_grey}❰ Sort history by frequency${colr_rst}\n" "--by-freq"
			printf "%s      ${colr_grey}❰ Sort history by score${colr_rst}\n" "--by-score"
		}
		# }}}

		# Navita's Clean Sub-options{{{
		__navita::Completions::GetCleanSubOptions() {
			local colr_grey && colr_grey="\033[1;38;2;122;122;122m"
			local colr_rst && colr_rst='\e[0m'

			printf "%s     ${colr_grey}❰ Remove invalid paths${colr_rst}\n" "--invalid-paths"
			printf "%s     ${colr_grey}❰ Remove ignored paths${colr_rst}\n" "--ignored-paths"
			printf "%s      ${colr_grey}❰ Remove custom paths${colr_rst}\n" "--custom-paths"
			printf "%s      ${colr_grey}❰ Clear the full history${colr_rst}\n" "--full-history"
		}
		# }}}

		local curr_word && curr_word="${COMP_WORDS[COMP_CWORD]}"
		local prev_word && prev_word="${COMP_WORDS[COMP_CWORD-1]}"

		if (( COMP_CWORD == 1 )); then
			if [[ "${curr_word}" == -* ]]; then
				local opt_selected
				if opt_selected="$( __navita::Completions::GetMainOptions | \
					${navita_depends["fzf"]} --ansi --prompt='❯ ' --info='inline: ❮ ' --info-command='echo -e "\x1b[33;1m${FZF_INFO%%/*}\x1b[m/${FZF_INFO##*/} Choose an option « Navita"' --height=~100% --nth=1 --with-nth=1,2 --delimiter=' ❰ ' --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${curr_word}" --bind=tab:down,btab:up --cycle)"; then
					COMPREPLY=( "${opt_selected%% *} " )
					printf '\e[5n'
				else
					__navita::Completions::CompleteDirectory
				fi
			else
				__navita::Completions::CompleteDirectory
			fi
		elif (( COMP_CWORD == 2 )); then
			case "${prev_word}" in
				"-P")
					if [[ "${curr_word}" == -* ]]; then
						local opt_selected
						if opt_selected="$( __navita::Completions::GetMainOptions | ${navita_depends["grep"]} -v -G '^-P ' | ${navita_depends["fzf"]} --ansi --prompt='❯ ' --info='inline: ❮ ' --info-command='echo -e "\x1b[33;1m${FZF_INFO%%/*}\x1b[m/${FZF_INFO##*/} Choose an option « Navita"' --height=~100% --nth=1 --with-nth=1,2 --delimiter=' ❰ ' --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${curr_word}" --bind=tab:down,btab:up --cycle )"; then
							COMPREPLY=( "${opt_selected%% *} " )
							printf '\e[5n'
						else
							__navita::Completions::CompleteDirectory
						fi
					else 
						__navita::Completions::CompleteDirectory
					fi
					;;
				"-H"|"--history")
					local opt_selected && opt_selected="$( __navita::Completions::GetHistorySubOptions | \
						${navita_depends["fzf"]} --ansi --prompt='❯ ' --info='inline: ❮ ' --info-command='echo -e "\x1b[33;1m${FZF_INFO%%/*}\x1b[m/${FZF_INFO##*/} Sort and view history « Navita"' --height=~100% --nth=1 --with-nth=1,2 --delimiter=' ❰ ' --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${curr_word}" --bind=tab:down,btab:up --cycle)" \
						&& COMPREPLY=( "${opt_selected%% *} " )
					printf '\e[5n'
					;;
				"-c"|"--clean")
					local opt_selected && opt_selected="$(__navita::Completions::GetCleanSubOptions | \
						${navita_depends["fzf"]} --ansi --prompt='❯ ' --info='inline: ❮ ' --info-command='echo -e "\x1b[33;1m${FZF_INFO%%/*}\x1b[m/${FZF_INFO##*/} Choose what to clean « Navita"' --height=~100% --nth=1 --with-nth=1,2 --delimiter=' ❰ ' --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${curr_word}" --bind=tab:down,btab:up --cycle)" \
						&& COMPREPLY=( "${opt_selected%% *} " )
					printf '\e[5n'
					;;
				*) 
					if [[ -z "${curr_word}" ]]; then
						local path_returned && path_returned="$(__navita::Completions::GetHighestRankDirectory "${prev_word}")"
						[[ -n "${path_returned}" ]] && COMPREPLY=( "${path_returned} " ) && printf '\e[5n'
					fi
					;;
			esac
		elif (( COMP_CWORD == 3 )) && [[ "${COMP_WORDS[1]}" == "-P" ]]; then
			case "${prev_word}" in
				"-H"|"--history")
					local opt_selected && opt_selected="$( __navita::Completions::GetHistorySubOptions | \
						${navita_depends["fzf"]} --ansi --prompt='❯ ' --info='inline: ❮ ' --info-command='echo -e "\x1b[33;1m${FZF_INFO%%/*}\x1b[m/${FZF_INFO##*/} Sort and view history « Navita"' --height=~100% --nth=1 --with-nth=1,2 --delimiter=' ❰ ' --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${curr_word}" --bind=tab:down,btab:up --cycle)" \
						&& COMPREPLY=( "${opt_selected%% *} " )
					printf '\e[5n'
					;;
				"-c"|"--clean")
					local opt_selected && opt_selected="$(__navita::Completions::GetCleanSubOptions | \
						${navita_depends["fzf"]} --ansi --prompt='❯ ' --info='inline: ❮ ' --info-command='echo -e "\x1b[33;1m${FZF_INFO%%/*}\x1b[m/${FZF_INFO##*/} Choose what to clean « Navita"' --height=~100% --nth=1 --with-nth=1,2 --delimiter=' ❰ ' --tiebreak=begin,index --select-1 --exit-0 --exact --layout=reverse --query="${curr_word}" --bind=tab:down,btab:up --cycle)" \
						&& COMPREPLY=( "${opt_selected%% *} " )
					printf '\e[5n'
					;;
				*) 
					if [[ -z "${curr_word}" ]]; then
						local path_returned && path_returned="$(__navita::Completions::GetHighestRankDirectory "${prev_word}")"
						[[ -n "${path_returned}" ]] && COMPREPLY=( "${path_returned} " ) && printf '\e[5n'
					fi
					;;
			esac
		elif [[ -z "${curr_word}" ]]; then
			local path_returned
			[[ "${COMP_WORDS[1]}" == "-P" ]] && path_returned="$(__navita::Completions::GetHighestRankDirectory "${COMP_WORDS[@]:2:$(( ${#COMP_WORDS[@]} - 3 ))}")" || path_returned="$(__navita::Completions::GetHighestRankDirectory "${COMP_WORDS[@]:1:$(( ${#COMP_WORDS[@]} - 2 ))}")"
			[[ -n "${path_returned}" ]] && COMPREPLY=( "${path_returned} " ) && printf '\e[5n'
		fi
		bind "set completion-ignore-case ${ignore_case_completion_default}"
	}

	complete -o nospace -F __navita::Completions "${NAVITA_COMMAND}"
elif [[ -n "${ZSH_VERSION}" ]]; then
	__navita::Completions() {
		local -a main_options history_sub_options clean_sub_options

		# Get the highest-ranked directory for tab completion{{{
		__navita::Completions::GetHighestRankDirectory() {
			# The function should be identical to the highest-ranked directory traversal part of the __navita::CDGeneral() function
			__navita::CDGeneral::GetPaths() {
				local line _path pwd_not_found=1
				while read -r line; do
					_path="${line%%:*}"
					if (( pwd_not_found )) && [[ "${_path}" == "${PWD}" ]]; then
						pwd_not_found=0
						continue
					fi
					printf "%s\n" "${_path}"
				done < "${NAVITA_HISTORYFILE}"
			}

			local srch_inc=""
			local srch_exc=""
			local end_of_str_anchor_found=0
			local last_search_type=0
			local pattern

			for pattern in "${@}"; do
				pattern="${pattern//./\\.}"
				# interpret special characters
				eval "pattern=$pattern"

				(( end_of_str_anchor_found == 0 )) && [[ "${pattern: -1}" == "$" ]] && end_of_str_anchor_found=1
				if [[ "${pattern:0:1}" == "!" ]]; then 
					srch_exc="${srch_exc}${pattern:1}|" 
					last_search_type=2
				else
					srch_inc="${srch_inc}(?=.*${pattern})"
					last_search_type=1
				fi
			done
			unset pattern

			[[ "${srch_exc: -1}" == "|" ]] && srch_exc="${srch_exc:0: -1}"
			if (( end_of_str_anchor_found == 0 )); then
				case "${last_search_type}" in
					"1")
						# inclusion search term
						srch_inc="${srch_inc:0:-1}\$)"
						;;
					"2")
						# exclusion search term
						srch_exc="${srch_exc}\$"
						;;
				esac
			fi

			if [[ -n "${srch_exc}" ]] && [[ -n "${srch_inc}" ]]; then
				__navita::CDGeneral::GetPaths | ${navita_depends["grep"]} -vP "${srch_exc}" | ${navita_depends["grep"]} -m 1 -P "${srch_inc}"
			elif [[ -z "${srch_exc}" ]] && [[ -n "${srch_inc}" ]]; then
				__navita::CDGeneral::GetPaths | ${navita_depends["grep"]} -m 1 -P "${srch_inc}"
			elif [[ -n "${srch_exc}" ]] && [[ -z "${srch_inc}" ]]; then
				__navita::CDGeneral::GetPaths | ${navita_depends["grep"]} -m 1 -vP "${srch_exc}"
			fi
		}
		# }}}

		main_options=(
			"-:Traverse to the previous working directory"
			"--:Search and traverse from history"
			"-P:Resolve symbolic links and traverse to the actual directory"
			"-H:View Navita's history of directory visits"
			"--history:View Navita's history of directory visits"
			"-c:Choose what to clear from history or clear all"
			"--clean:Choose what to clear from history or clear all"
			"-s:Recursively search and traverse sub-directories"
			"--sub-search:Recursively search and traverse sub-directories"
			"-S:Search and traverse 1-level below the parent directories"
			"--super-search:Search and traverse 1-level below the parent directories"
			"-h:View help message"
			"--help:View help message"
			"-v:Navita's version information"
			"--version:Navita's version information"
		)

		history_sub_options=(
			'--by-freq:Sort history by frequency'
			'--by-time:Sort history by access time'
			'--by-score:Sort history by score'
		)

		clean_sub_options=(
			'--invalid-paths:Remove invalid paths'
			'--ignored-paths:Remove ignored paths'
			'--custom-paths:Remove custom paths'
			'--full-history:Clear the full history'
		)

		if (( CURRENT == 2 )); then
			# 1st argument
			if [[ "${words[CURRENT]}" == -* ]]; then
				_describe -t main_options "Navita's main-options" main_options
			else
				_path_files -/ '*(-/)'
			fi
		elif (( CURRENT == 3 )); then
			# 2nd argument
			case "${words[CURRENT-1]}" in
				"-P")
					if [[ "${words[CURRENT]}" == -* ]]; then
						unset 'main_options[3]'
						_describe -t main_options "Navita's main-options" main_options
					else
						_path_files -/ '*(-/)'
					fi
					;;
				"-H"|"--history")
					_describe -t history_sub_options "Navita's history sub-options" history_sub_options;;
				"-c"|"--clean")
					_describe -t clean_sub_options "Navita's clean sub-options" clean_sub_options;;
				*)
					if [[ -z "${words[CURRENT]}" ]]; then
						local -a path_returned && path_returned=( "$(__navita::Completions::GetHighestRankDirectory "${words[CURRENT-1]}")" )
						[[ -n "${path_returned[1]}" ]] && _describe -t path_returned "Highest-ranked directory" path_returned
					fi
					;;
			esac
		elif (( CURRENT == 4 )) && [[ "${words[2]}" == "-P" ]]; then
			# 3rd argument with `-P` as the 1st argument
			case "${words[CURRENT-1]}" in
				"-H"|"--history")
					_describe -t history_sub_options "Navita's history sub-options" history_sub_options;;
				"-c"|"--clean")
					_describe -t clean_sub_options "Navita's clean sub-options" clean_sub_options;;
				*)
					if [[ -z "${words[CURRENT]}" ]]; then
						local -a path_returned && path_returned=( "$(__navita::Completions::GetHighestRankDirectory "${words[CURRENT-1]}")" )
						[[ -n "${path_returned[1]}" ]] && _describe -t path_returned "Highest-ranked directory" path_returned
					fi
					;;
			esac
		elif [[ -z "${words[CURRENT]}" ]]; then
			local -a path_returned 
			[[ "${words[2]}" == "-P" ]] && path_returned=( "$(__navita::Completions::GetHighestRankDirectory "${words[@]:2:$((CURRENT - 2))}")" ) || path_returned=( "$(__navita::Completions::GetHighestRankDirectory "${words[@]:1:$((CURRENT - 2))}")" )
			[[ -n "${path_returned[1]}" ]] && _describe -t path_returned "Highest-ranked directory" path_returned
		fi
	}

	compdef __navita::Completions "__navita__"
fi
# }}}

