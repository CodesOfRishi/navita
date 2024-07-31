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
	local colr91 && colr91='\e[01;91m'
	local colr_rst && colr_rst='\e[0m'

	local line=""
	while read -r line; do
		printf '%s' "${line}"
		local error="$( find ${line} -maxdepth 0 -exec cd {} \; 2>&1 >/dev/null )"
		if [[ -n "${error}" ]]; then 
			printf " (${colr91}${error}${colr_rst})"
		fi
		echo
	done < ${navita_historyfile}
}

__navita::CleanHistory() { 
	# Possible options:
	# 	complete clean the history file
	# 	remove only invalid paths
	
	__navita::CleanHistory::EmptyHistoryFile() {
		> "${navita_historyfile}"
		[[ $? -eq 0 ]] && printf '%s\n' "${navita_historyfile} cleaned."
		return $?
	}

	printf '%s\n' "Choose any one: "
	printf '%s\n' "1. Remove only invalid paths."
	printf '%s\n' "2. Empty the history."
	echo
	local user_choice
	read -p "Choice? (1 or 2): " user_choice

	if [[ ${user_choice} -eq 1 ]]; then
		# will write code later
		return 0
	elif [[ ${user_choice} -eq 2 ]]; then
		__navita::CleanHistory::EmptyHistoryFile
	else
		printf "Invalid input!"
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

	echo ${PWD} >> "${navita_historyfile}"
	awk -i inplace '!seen[$0]++' "${navita_historyfile}" # remove duplicates
	__navita::KeepHistoryWithinLimit
	return $?
}

__navita__() {

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
	elif [[ $1 == "--history" ]] || [[ $1 == "-h" ]]; then
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

