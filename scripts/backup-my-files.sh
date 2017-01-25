#!/usr/bin/env bash
###################################################################
# backs up my file using rsync from one host to another
#
# author: smazumder
#
###################################################################
set -e
declare -i RETAIN=30
declare -r VERSION="1.01"

usage() {
cat <<EOM

backup-my-files - An incremental daily backup script using rsync
Copyright (c)2016 smazumder <smtechnocrat@gmail.com>
Version $VERSION

This script comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it
under certain conditions. See CC BY-NC-SA 4.0 for details.
https://creativecommons.org/licenses/by-nc-sa/4.0/

Usage
 `basename $0` [OPTIONS] SOURCE TARGET

Options
 -r NUM 		number of days to keep old backups
 -e FILE		specify (optional) rsync excludes filename
 -d			dry run
 -v			increase verbosity
 -h			show this message
 -V			show version number

Example
 backup-my-files -v -e my_exludes / /backup/

EOM
}

parse_commandline_arguments() {
	while [[ ${1:0:1} = "-" ]] ; do
		local n=1
		local l=${#1}
		while [[ $n -lt $l ]] ; do
			case ${1:$n:1} in
				h)
					usage
					exit 0
					;;
				r)
					if [[ $n -ne $(($l-1)) || ! -n ${2} ]]; then
						usage
						exit 1
					fi
					if [[ ${2} == ?(-)+([0-9]) ]]; then
						RETAIN="${2}"
					else
						printf "Error: -r must be followed by an integer\n" >&2
						exit 2
					fi
					shift
					;;
				e)
					if [[ $n -ne $(($l-1)) || ! -n ${2} ]]; then
						usage
						exit 1
					fi
					if [[ -f $2 ]]; then
						EXCLUDE="${2}"
						shift
					else
						printf "Error: Excludes file \"%s\" not found\n" "${2}" >&2
						exit 3
					fi
					;;
				v)
					VERBOSE="--verbose --progress"
					;;
				V)
					printf "Hactar Version %s\n" "${VERSION}"
					exit 0
					;;
				d)	DRYRUN="--dry-run"
					;;
				*)
					printf "Error: Unknown option %s\n" "${1}" >&2
					exit 4
					;;
			esac
			n=$(($n+1))
		done
		shift
	done

	# No arguments where given
	if [[ ! -n ${1} ]]; then
		usage
		exit 0
	fi

	# Target directory is missing
	if [[ ! -n ${2} ]]; then
		printf "Error: Please specify target directory\n" >&2
		exit 5
	fi

	SOURCE="${1}"
	TARGET="${2}"
}

# Main run function 
run_backup() {
	# Do we have a backup to hardlink against?
	if [[ -d ${TARGET}/`date -I -d "1 day ago"` ]]; then
		declare -r linkdest="--link-dest=${TARGET}/$(date -I -d "1 day ago")"
	fi

	# Do we use a default excludes file?
	if [[ -f "/etc/hactar.excludes" && $EXCLUDE = "" ]]; then
		EXCLUDE="/etc/hactar.excludes"
	fi

	# Run rsync with passed parameters
	rsync --archive --one-file-system --hard-links --human-readable \
		--inplace --numeric-ids --delete --delete-excluded --exclude-from=${EXCLUDE} \
		${linkdest} ${SOURCE} ${TARGET}/`date -I` ${DRYRUN} ${VERBOSE}
}

delete_oldest_backup() {
	declare -r oldest=`date -I -d "${RETAIN} days ago"`
	if [ -d ${TARGET}/${oldest} ]; then
		logger -t hactar "Deleting old backup from ${oldest}"
		rm -r ${TARGET}/${oldest}
	fi
}

main() {
	parse_commandline_arguments "$@"

	declare -r start=$(date +%s)
	logger -t hactar "Starting backup from \"${SOURCE}\" to \"${TARGET}`date -I`\""

	run_backup

	delete_oldest_backup

	declare -r end=$(date +%s)
	declare -r runtime=$(python -c "print '%u minutes %02u seconds' % ((${end} - ${start})/60, (${end} - ${start})%60)")
	logger -t hactar "Backup from \"${SOURCE}\" to \"${TARGET}`date -I`\" took ${runtime}"
}

main "$@"
