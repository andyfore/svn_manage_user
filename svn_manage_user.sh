#!/bin/bash
#
# Script name: svn_manage_user.sh
# Purpose: utility script designed to facilitate the management of the SVN repository
# Author: Andrew Fore, andy.fore@arfore.com
# Date originated: 2015-07-27

## Non-static variables
# Variable name: svn_repo
# Purpose: stores the item number selected in the list of repositories

# Variable name: svn_user
# Purpose: stores the username input read from standard input

# Variable name: svn_action
# Purpose: stores the item number selected in the list of possible actions presented to the user

## Static variables
# Variable name: htpasswd_binary
# Purpose: stores the full path to the htpasswd binary location
htpasswd_binary="/usr/bin/htpasswd"

# Variable name: htpasswd_file
# Purpose: stores the full path to the htpasswd file location
htpasswd_file="/usr/local/svnacl/svn-user-auth"

# Variable name: rconn_acl
# Purpose: stores the full path to the ACL file
#          for the rconnection SVN repository
rconn_acl="/usr/local/svnacl/rconnection_accesslist"

# Variable name: retail_acl
# Purpose: stores the full path to the ACL file
#          for the retail SVN repository
retail_acl="/usr/local/svnacl/accesslist"

clear
echo "Register SVN User Management Utility"
echo
echo "Please select the desired action."
echo "Available actions:"
echo "1. Add user"
echo "2. Remove user"
echo "3. Change user password"
echo "4. Exit with no changes"
echo
echo -n "Please enter selection: "
read svn_action

function info {
echo "Info: this utility script is designed to facilitate the management of the SVN repository (or more than one, since it is scalable)"
echo "      that is configured to use an htpasswd mechanism for authentication purposes."
}

function find_user {

	# This function takes two arguments that are stored in variables $repo and $user
	# The first argument is the repository that we need to check for existing access.
	# The second argument is the username we are trying to add.
	# If the user is found in the supplied repository with either read-only or read-write
	# permissions, then an error message is returned to standard output and the script exits.

	repo=$1
	user=$2

	if `grep -Fxq "$user = r" $repo`; then
		echo "A user with the username of $user"
		echo "was found in the $repo repository with read-only permissions."
	fi

	if `grep -Fxq "$user = rw" $repo`; then
		echo "A user with the username of $user"
		echo "was found in the $repo repository with read-write permissions."
	fi

	echo "Please check your data and attempt the operation again."
	exit

}

function find_user_quiet {

	# This function takes one argument that is stored in the variable $user
	# If the user is found in either repository or the htpasswd access file then the
	# variable $user_found is set to true and the function completes.

	user=$1
	user_found=false

	if (`grep -Fxq "$user = rw" $rconn_acl $retail_acl`) || (`grep -Fxq "$user = r" $rconn_acl $retail_acl`) || (`grep -Fq "$user:" $htpasswd_file`);
	then
		user_found=true
	fi

}

function check_password {

	# This function takes two arguments that are stored in the variables $entry and $reentry
	# It will take both inputs and run a string comparison to ensure that they match
	# in addition to running the password through the cracklib-check utility that checks
	# the password for complexity and length. If the check pass then a boolean variable
	# $passwd_good is set to true and the function completes.

	local entry=$1
	local reentry=$2
	local result="$(cracklib-check <<<"$entry")"
	local tokens=( $result )

	passwd_good=false

	if [ "${tokens[1]}" == "OK" ] && [ "${tokens[1]}" == "OK" ] && [ "$entry" == "$reentry" ];
	then
		passwd_good=true
	fi

}

function add_svn_user {

	# This function presents the operator with a series of prompts to answer and based on
	# a series of predetermined operations adds the user to the desired SVN repository
	# as well as creating the desired user in the htpasswd authentication file.

	clear
	read -r -p "Please enter the username: " svn_user
    read -s -p "Please enter the new password: " pass1
    echo
    read -s -p "Please re-enter the new password: " pass2
    echo

    check_password $pass1 $pass2
    if [ $passwd_good = true ];
    then
		echo
		echo "Please enter the desired SVN repository."
		echo "Available repositories:"
		echo "1. rconnection"
		echo "2. retail"
		echo "3. Both rconnection and retail"
		echo
		echo -n "Please select the repository: "
		read svn_repo
		echo

		# Before continuing look to see if user exists
		if [ $svn_repo -eq "1" ]; then
			find_user $rconn_acl $svn_user
		else
			if [ $svn_repo -eq "2" ]; then
				find_user $retail_acl $svn_user
			fi
		fi

		echo "Please enter the access level:"
		echo "1. Read/Write"
		echo "2. Read Only"
		echo
		echo -n "Please select the access level: "
		read access_level
		echo

		if [[ $access_level -eq "1" ]]; then
			lvl_txt="rw"
		fi

		if [[ $access_level -eq "2" ]]; then
			lvl_txt="r"
		fi

		case $svn_repo in
			1) $htpasswd_binary -b -m $htpasswd_file $svn_user $pass1
			   echo "$svn_user = $lvl_txt" >> $rconn_acl
			   ;;
			2) $htpasswd_binary -b -m $htpasswd_file $svn_user $pass1
			   echo "$svn_user = $lvl_txt" >> $retail_acl
			   ;;
                        3) $htpasswd_binary -b -m $htpasswd_file $svn_user $pass1
                           echo "$svn_user = $lvl_txt" >> $retail_acl
                           echo "$svn_user = $lvl_txt" >> $rconn_acl
                           ;;
		esac
	else
		echo "Password was either too short, not complex enough or a null/empty value."
		echo "Please try your operation again."
		exit
	fi

}

function del_svn_user {

	# This function presents the operator with a series of prompts to answer and based on
	# a series of predetermined operations removes the user from the SVN system

	clear
	read -r -p "Please enter the username: " svn_user
	echo
    find_user_quiet $svn_user
    if [ $user_found = true ];
    then
		echo $user_found
		echo "Removing $svn_user from ACLs..."
		echo "Processing rconnection repository..."
		sed -c --in-place=.`date +"%Y%m%d"` "/${svn_user} = rw/d" $rconn_acl
		sed -c --in-place=.`date +"%Y%m%d"` "/${svn_user} = r/d" $rconn_acl
		echo
		echo "Processing retail repository..."
		sed -c --in-place=.`date +"%Y%m%d"` "/${svn_user} = rw/d" $retail_acl
		sed -c --in-place=.`date +"%Y%m%d"` "/${svn_user} = r/d" $retail_acl
		echo "User $svn_user removed from SVN ACLs."
		echo
		echo "Removing $svn_user from password file..."
		sed -c --in-place=.`date +"%Y%m%d"` "/${svn_user}:/d" $htpasswd_file
    else
		echo "User not found."
		echo "Please check your inputs and try again."
		exit
    fi

}

function update_svn_user {

	# This function presents the operator with a series of prompts to answer and based on
	# a series of predetermined operations updates the user password in the htpasswd
	# authentication system.

	clear
	read -r -p "Please enter the username: " svn_user
    find_user_quiet $svn_user
    if [ $user_found = true ];
    then
		read -s -p "Please enter the new password: " pass1
		echo
		read -s -p "Please re-enter the new password: " pass2
		echo

		check_password $pass1 $pass2
		if [ $passwd_good = true ];
		then
			$htpasswd_binary -b -m $htpasswd_file $svn_user $pass1
		else
			echo "Password was either too short, not complex enough or a null/empty value."
			echo "Please try your operation again."
			exit
		fi
    else
		echo "User not found."
		echo "Please check your inputs and try again."
    fi
}

case $svn_action in
    1) add_svn_user;;
    2) del_svn_user;;
    3) update_svn_user;;
    4) exit;;
    *) info;;
esac
