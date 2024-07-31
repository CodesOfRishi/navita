# navita variables
export navita_historyfile="${XDG_CONFIG_HOME}/navita/path-history"
export navita_historyfilesize=50

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
	done < ${navita_historyfile}
}

__navita::CleanHistory() { 

	__navita::CleanHistory::EmptyHistoryFile() {
		> "${navita_historyfile}"
		[[ $? -eq 0 ]] && printf '%s\n' "${navita_historyfile} cleaned."
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
		done < ${navita_historyfile}

		local index_reduced=0
		for i in "${line_no_todel[@]}"; do
			sed -i -e "$(( ${i} - ${index_reduced} ))d" ${navita_historyfile}
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

	# keep the path-history file within the $navita_historyfilesize
	__navita::KeepHistoryWithinLimit() { 
		if [[ $( wc -l < "${navita_historyfile}" ) -gt "${navita_historyfilesize}" ]]; then
			local extra_linecount=$(( $( wc -l < "${navita_historyfile}" ) - ${navita_historyfilesize} ))
			sed -i 1,${extra_linecount}d ${navita_historyfile}
			return $?
		fi
		return 0
	}

	printf "${PWD}\n" >> "${navita_historyfile}"
	awk -i inplace '!seen[$0]++' "${navita_historyfile}" # remove duplicates
	__navita::KeepHistoryWithinLimit
	return $?
}

__navita__() {

	local colr91 && colr91='\e[01;91m'
	local colr_rst && colr_rst='\e[0m'

	if [[ $1 == "--" ]]; then
		local fzf_query="${@:2}"
		if [[ -z "${fzf_query}" ]]; then
			local path_returned=$( cat "${navita_historyfile}"  | fzf --tac --prompt="navita> " --select-1 --exit-0 )
		else 
			local path_returned=$( cat "${navita_historyfile}"  | fzf --tac --prompt="navita> " --select-1 --exit-0 --query="${fzf_query}" )
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
		if [[ -z "$1" ]]; then
			builtin cd
		else
			builtin cd "$1"
			[[ $? -eq 0 ]] && __navita::UpdatePathHistory && return 0
			return 1
		fi
	fi
}

