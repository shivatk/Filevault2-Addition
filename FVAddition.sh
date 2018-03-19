#!/bin/sh
#
# This script is to be run for every user login via LaunchAgent. This will check
# if the logged in user is already a part of the FileVault list. If not, this will
# prompt the user for their credentials and add them.

LogFile=`echo /tmp/FVAddition.log`

/bin/rm -rf $LogFile 2>/dev/null

AdminUsername='administrator'
AdminPassword='honda:hral'

function write_log() {

	if [ $? -eq 0 ]; then
		/bin/echo "[`date`] - $1" >> $LogFile
	else
		/bin/echo "[`date`] - $2" >> $LogFile
		exit 1
	fi
}

write_log 'Staring script' ''

## Getting current user
CurrentUser=`/usr/bin/stat -f%Su /dev/console`
write_log 'Retrieved current user' 'Unable to retrieve username. Exiting.'

echo "[`date`]"' - Current User is '$CurrentUser >> $LogFile

## Getting OS version
OSMinorVersion=`/usr/bin/sw_vers -productVersion | awk -F. {'print $2'}`

if [ $OSMinorVersion -le 12 ]; then
	write_log 'OS Version supported for script. Continuing...' ''
else
	write_log '' 'OS Version not supported for script. Exiting'
	exit 1
fi

## Getting encryptin status

encResult=`fdesetup status | grep -i 'FileVault is on.'`

if [ -n "$encResult" ]; then
	write_log 'Machine encrypted. Continuing...' ''
else
	write_log '' 'Machine not encrypted. Exiting.'
fi

## Checking if current user is a part of FileVault

write_log 'Checking if user is a part of FileVault' ''

CheckUser=$(sudo fdesetup list | grep -i "$CurrentUser")

if [ -z "$CheckUser" ]; then
	write_log 'User not part of FileVault. Trying to add user.' ''
else
	write_log '' 'User part of FileVault. No actions required. Exiting'
fi

## Getting logged in's user password

UserPassword=$(/usr/bin/osascript <<EOT
tell application "System Events"
activate
display dialog "Please enter your login password:" default answer "" buttons {"Continue"} default button 1 with hidden answer
if button returned of result is "Continue" then
set pwd to text returned of result
return pwd
end if
end tell
EOT)

write_log 'Retrieved user password' 'Unable to retrieve password. Exiting'

## Creating input plist

createPlist() {
    echo '<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    <key>Username</key>
    <string>'$AdminUsername'</string>
    <key>Password</key>
    <string>'$AdminPassword'</string>
    <key>AdditionalUsers</key>
    <array>
        <dict>
            <key>Username</key>
            <string>'$CurrentUser'</string>
            <key>Password</key>
            <string>'$UserPassword'</string>
        </dict>
    </array>
    </dict>
    </plist>' > /Users/Shared/input.plist
}

createPlist

write_log 'input plist created.' 'Unable to create input plist. Exiting.'

## Adding User to FileVault

sudo fdesetup add -i < /Users/Shared/input.plist 2>> $LogFile

## Checking if user has been added to FileVault


CheckUser=$(sudo fdesetup list | grep -i "$CurrentUser")

if [ -n "$CheckUser" ]; then
	write_log 'User added successfully.' ''
else
	write_log '' 'Unable to add user.'
fi

exit 0
