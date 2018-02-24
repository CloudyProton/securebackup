#!/usr/bin/env bash
# Written by: https://github.com/CloudyProton

number_of_backups_to_save=10

folders_to_back_up=(\
"$HOME/Desktop/../Desktop" \
"$HOME/Documents/../Documents" \
"$HOME/Downloads/../Downloads" \
"$HOME/Music/../Music" \
"$HOME/Pictures/../Pictures" \
"$HOME/Videos/../Videos" \
)

# Add directory paths with "$HOME/DirToSave/../DirToSave" format to flag them for archival.
# number_of_backups_to_save represents the amount of archives that will be held trailing every new backup archive.

recommended_packages=(\
"smartmontools" \
"file-roller" \
"tar" \
"gnupg" \
"rsync" \
"coreutils" \
"clamav" \
)

main(){
	while true ; do
	clear
	echo
	echo "------------------------------"
	echo "Secure backup script"
	echo "A bash script to backup files and encrypt the resulting archive with GPG"
	echo "------------------------------"
	echo
	echo "A. Backup system"
	echo "B. Restore ststem"
	echo "C. Check packages"
	echo "D. Exit script"
	echo
	echo -n "Enter a selection: "
	read -r option	
		case "$option" in
				
		[Aa])
			backupPrep
		;;
		[Bb])
			restorePrep
		;;
		[Cc])
			checkRecommends
		;;
		[Dd])
			exit 0
		;;
		*)
			echo "Enter a valid selection from the menu - options include A to D"
			sleep 2
		;;	
		esac 	
	done
}

backupPrep(){
	backup_name="${HOSTNAME}"_$(date +%Y-%m-%d)
	backup_drive="$PWD"
	if [ -f /usr/sbin/smartctl ]; then
		boot_drive=$(df / | grep / | cut -d' ' -f1)
		# Hide distracting readout information.
		sudo smartctl -H "$boot_drive" | sed '1d;2d;3d;4d'
		this_drive_mount=$(df "$backup_drive" | sed '1d' | cut -d' ' -f1)
		sudo smartctl -H "$this_drive_mount" | sed '1d;2d;3d;4d'
	fi

	if [ -f /usr/bin/clamscan ]; then
		echo -n "Scan system drive? [y/n]: "
		read -r choice
		if [[ "$choice" == Y ]] || [[ "$choice" == y ]]; then
			sudo freshclam
			# Whole system scan including attached drives, only reads out infected items.
			sudo clamscan -ir --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/mnt /
		fi
	fi

	# Wait for drive health readout if ClamAV is not present.
	if [ ! -f /usr/sbin/smartctl ]; then
		sleep 5
	fi

	# Count number of mounted external drives to check if copies can be distributed.
	for f in $(ls "/media/$USER/"); do number_of_drives=$((number_of_drives+=1)); done
	if [ $number_of_drives -gt 1 ]; then
		# Build array of all mounted drive paths to subract $this_drive_path from.
		all_mounted_drives=($(for g in $(ls "/media/$USER/"); do echo "/media/$USER/$g"; done))
		# Subtract operating drive path from array.
		for h in "${all_mounted_drives[@]}"; do
			if [ "$h" != "${backup_drive%/*}" ]; then #ONLY STRIPS LAST DIRECTORY, DOESN'T RELIABLY GRAB CORE DRIVE PATH.
				other_mounted_drives+=("$h")
			fi
		done
		for j in "${other_mounted_drives[@]}"; do
			echo -n "Distribute backup copy to $j also? [y/n]: "
			read -r choice
			if [[ "$choice" = Y ]] || [[ "$choice" = y ]]; then
				selected_mounted_drives+=("$j")
			fi
		done
	fi

	# Prompt to set flag for review of unencrypted archive before deleting.
	# This is done so that user choices are addressed before starting the long process of backing up. This facilitates a mostly unattended session.
	echo -n "Review unencrypted copy before deleting? [y/n]: "
	read -r choice
	if [[ "$choice" = Y ]] || [[ "$choice" = y ]]; then
		review_unencrypted=true
	else
		review_unencrypted=false
	fi
	createArchive
}

createArchive(){
	# Archive and compress the specified directories.
	echo "$backup_drive $backup_name"
	echo "${folders_to_back_up[@]}"
	tar -czpf "$backup_drive"/"$backup_name.tar.gz" "${folders_to_back_up[@]}" #--exclude=".*"
	# Encrypt the compressed backup archive.
	gpg -c --use-agent --cipher-algo aes256 "$backup_drive/$backup_name.tar.gz"
	# Reference the flag made for unencrypted backup review.
	if [ $review_unencrypted = true ]; then
		file-roller "$backup_name.tar.gz"
	fi
	# IF PASSWORD MATCH FAILS, WORKING ARCHIVE GETS DELETED
	shred -u --iterations=1 "$backup_drive"/"$backup_name".tar.gz
	rotateLibrary
}

rotateLibrary(){
	# String manipultion stripping backup file name down to date only.
	for i in *_*-*-*.tar.gz.gpg; do
		count=$((count+=1))
		prefix_removed=${i#*_}
		dashes_removed=${prefix_removed//-/}
		suffix_removed=${dashes_removed%.tar.gz.gpg}
		output[$count]=$suffix_removed
	done
	# Order array elements in reverse to count up from oldest until max save limit is met.
	sorted=($(for i in "${output[@]}"; do echo "$i"; done | sort -nr))
	for x in ${sorted[@]:$number_of_backups_to_save}; do
		# Delete all oldest archives up to number_of_backups_to_save.
		rm *_${x:0:4}-${x:4:2}-${x:6:2}.tar.gz.gpg
	done
	distributeCopy
}

distributeCopy() {
	# Iterate over chosen extra drives to deliver backup copies.
	for j in "${selected_mounted_drives[@]}"; do
		rsync -amE --delete --exclude=".*" "$backup_drive" "$j/${PWD##*/}"
	done
}

restorePrep(){
	# String manipultion stripping backup file name down to date with dashes for selection.
	for i in *_*-*-*.tar.gz.gpg; do
		count=$((count+=1))
		prefix_removed=${i#*_}
		suffix_removed=${prefix_removed%.tar.gz.gpg}
		output[$count]=$suffix_removed
	done
	# Create new array with reversed ordered elements.
	sorted=($(for i in "${output[@]}"; do echo "$i"; done | sort -nr))
	restoreSelection
}

restoreSelection(){
	highlighted=0
	while :
	do
	# If statement loop to wrap edges in selection.
	if [ "$highlighted" == "${#sorted[*]}" ]; then
		highlighted=0
	elif [ "$highlighted" == "-${#sorted[*]}" ]; then
		highlighted=0
	fi
		clear
		echo "[,/.]change, [a]ccept, [q]uit."
		echo "⟸  ${sorted[$highlighted]} ⟹  "
		read -rsn1 direction
		case $direction in
			# Advance to next cycle with modified $highlighted value or selected option.
			.)
			highlighted=$((highlighted+=1)) ;;
			,)
			highlighted=$((highlighted-=1)) ;;
			a)
			decryptBackup ;;
			q)
			exit ;;
		esac
	done
}

decryptBackup(){
	backup_to_restore="${sorted[$highlighted]}"
	gpg --decrypt *_"$backup_to_restore".tar.gz.gpg > Decrypted_"$backup_to_restore".tar.gz
	dirMatch
}

dirMatch(){
	# Allows spaces in restoration file names.
	old_IFS="$IFS"; IFS=$'\n'
	# Build top-level archived directories into an array while removing leading "/".
	directories_in_archive=($(for t in $(tar --exclude="*/*" -tzf "Decrypted_$backup_to_restore.tar.gz"); do echo "${t%'/'}"; done))
	IFS="$old_IFS"
	iteration=0
	for i in "${directories_in_archive[@]}"; do
		# For syncing associative array with restoreArchive().
		iteration=$((iteration+=1))
		check=0
		for j in "${folders_to_back_up[@]}"; do
			# Comparing active item against folders_to_backup for match.
			check=$((check+=1))
			if [[ "$j" == *"$i" ]]; then
				# Match found.
				restore_source[$iteration]="$i"
				restore_dest[$iteration]="${j%$i/../*}"
				break
			elif [ "$check" == "${#folders_to_back_up[*]}" ]; then
				echo -n "$i path not found, enter custom path: "
				read -r custom_path
				restore_dest[$iteration]="$custom_path"
			fi
		done
	done
	restoreArchive
}

restoreArchive(){
	iteration=0
	for k in "${restore_source[@]}"; do
		# Sync associative array with dirMatch().
		iteration=$((iteration+=1))
		# Extract individual archived file to external (see: specified) directory.
		tar --skip-old-files -xzf "Decrypted_$backup_to_restore.tar.gz" -C "${restore_dest[$iteration]}" "${restore_source[$iteration]}"
	done
	# Securely remove temporary unencrypted restoration archive.
	shred -u --iterations=1 "Decrypted_$backup_to_restore.tar.gz"
	exit
}

checkRecommends(){
	# Check presence of each package script uses
	clear
	for l in "${recommended_packages[@]}"; do
		dpkg -s $l > /dev/null
		if [[ "$?" == "0" ]]; then
			echo "$l is installed"
		elif [[ "$?" == "1" ]]; then
			echo "$l is not installed"
			recommends_missing=true
		fi
	done
		# Prompt user to install recommended packages if not present
		if [ "$recommends_missing" == true ]; then
			echo -n "Would you like to install missing recommended packages? [y/n]: "
			read -r choice
			if [[ "$choice" = Y ]] || [[ "$choice" = y ]]; then
				sudo apt-get install "${recommended_packages[@]}"
			else
				main
			fi
		fi
	main
}

main
