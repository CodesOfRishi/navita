# navita variables
export NAVITA_HISTORYFILE="${XDG_CONFIG_HOME}/navita/path-history"
export NAVITA_HISTORYFILE_SIZE=50

# create configuration file(s) for Navita
if [[ ! -d "${XDG_CONFIG_HOME}/navita" ]]; then 
	mkdir -p "${XDG_CONFIG_HOME}/navita"
	touch "${XDG_CONFIG_HOME}/navita/path-history"
	printf '%s\n' "Navita: Created ${XDG_CONFIG_HOME}/navita/path-history"
elif [[ ! -f "${XDG_CONFIG_HOME}/navita/path-history" ]]; then 
	touch "${XDG_CONFIG_HOME}/navita/path-history"
	printf '%s\n' "Navita: Created ${XDG_CONFIG_HOME}/navita/path-history"
fi

__navita::PrintHistory() { 

	local line=""
	while read -r line; do
		printf '%s' "${line}" | sed "s|^${HOME}|~|g"
		local error="$( find ${line} -maxdepth 0 -exec cd {} \; 2>&1 >/dev/null )"
		if [[ -n "${error}" ]]; then 
			printf " (${colr91}${error}${colr_rst})"
		fi
		printf "\n"
	done < ${NAVITA_HISTORYFILE}
}

__navita::CleanHistory() { 

	__navita::CleanHistory::EmptyHistoryFile() {
		> "${NAVITA_HISTORYFILE}"
		[[ $? -eq 0 ]] && printf '%s\n' "${NAVITA_HISTORYFILE} cleaned."
		return $?
	}

	__navita::CleanHistory::RemoveInvalidPaths() {
		# the line numbers that needs to be deleted from the history file, will be stored in an array
		# using sed, delete those lines in-place

		declare -a line_no_todel
		local line_no=1
		local line
		
		while read -r line; do
			local error="$( find ${line} -maxdepth 0 -exec cd {} \; 2>&1 >/dev/null )"
			if [[ -n "${error}" ]]; then 
				# printf "To Delete: ${line_no}: ${line} (${colr91}${error}${colr_rst})\n"
				line_no_todel+=(${line_no})
			fi
			line_no=$(( ${line_no} + 1 ))
		done < ${NAVITA_HISTORYFILE}

		local index_reduced=0
		for i in "${line_no_todel[@]}"; do
			sed -i -e "$(( ${i} - ${index_reduced} ))d" ${NAVITA_HISTORYFILE}
			index_reduced=$(( ${index_reduced} + 1 ))
		done
	}

	printf '%s\n' "Choose any one: "
	printf '%s\n' "1. Remove only invalid paths."
	printf '%s\n' "2. Empty the history."
	printf "\n"
	local user_choice
	read -p "Choice? (1 or 2): " user_choice

	if [[ ${user_choice} -eq 1 ]]; then
		__navita::CleanHistory::RemoveInvalidPaths
	elif [[ ${user_choice} -eq 2 ]]; then
		__navita::CleanHistory::EmptyHistoryFile
	else
		printf "Invalid input!\n" 1>&2
		return 1
	fi
}

# update the path-history file
__navita::UpdatePathHistory() { 
	if [[ ! -s "${NAVITA_HISTORYFILE}" ]]; then 
		printf "${PWD}\n" > "${NAVITA_HISTORYFILE}"
	else
		sed -i "1i ${PWD}" "${NAVITA_HISTORYFILE}" 
	fi

	awk -i inplace '!seen[$0]++' "${NAVITA_HISTORYFILE}" # remove duplicates
	sed -i "$(( $NAVITA_HISTORYFILE_SIZE + 1 )),\$"d "${NAVITA_HISTORYFILE}" # keep the path-history file within the $NAVITA_HISTORYFILE_SIZE
	return $?
}

__navita__() {

	local colr91 && colr91='\e[01;91m'
	local colr_rst && colr_rst='\e[0m'

	if [[ $1 == "--" ]]; then
		local fzf_query="${@:2}"
		if [[ -z "${fzf_query}" ]]; then
			local path_returned=$( cat "${NAVITA_HISTORYFILE}"  | fzf --prompt="navita> " --select-1 --exit-0 )
		else 
			local path_returned=$( cat "${NAVITA_HISTORYFILE}"  | fzf --prompt="navita> " --select-1 --exit-0 --query="${fzf_query}" )
		fi
		builtin cd "${path_returned}"
		return $?
	elif [[ $1 == "-" ]]; then
		builtin cd -
		[[ $? -eq 0 ]] && __navita::UpdatePathHistory
	elif [[ $1 == "--history" ]] || [[ $1 == "-H" ]]; then
		__navita::PrintHistory | bat
	elif [[ $1 == "--clean" ]] || [[ $1 == "-c" ]]; then
		__navita::CleanHistory
	else
		builtin cd "${@}"
		[[ $? -eq 0 ]] && __navita::UpdatePathHistory && return 0
		return 1
	fi
}

