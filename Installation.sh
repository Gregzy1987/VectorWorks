#!/bin/bash
#VectorWorks 2025 Silent Installer
# Reference: https://forum.vectorworks.net/index.php?/articles.html/articles/how-to/installation/command-line-installation-of-vectorworks-2025-r923/

###
# Variables
###

loggedInUser=$("/usr/bin/stat" -f%Su "/dev/console")
loggedInUserPlist="/Users/$loggedInUser/Library/Preferences/com.apple.dock.plist"
myUid=$(id -u "$loggedInUser")
myGid=$(id -g "$loggedInUser")
scriptLog="/var/log/VectorWorks-Installation.log"
commandLog="/var/log/VectorWorks-Commands.log"
YNAME="$4"

###
# Functions
###

# Logging Checks
function updateScriptLog() {
    echo -e "$( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}

function logFileCheck() {

    # Checking log file exists
    if [[ ! -e ${commandLog} ]];then
        touch ${commandLog}
    else
        updateScriptLog "Command log exists"
    fi
}

# Swift Dialog Check
function dialogCheck() {

    # Checking if Swift Dialog is installed
    if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
        updateScriptLog "swiftDialog not found. Installing..."
        # Get the URL of the latest PKG From the Dialog GitHub repo
        dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

        # Expected Team ID of the downloaded PKG
        expectedDialogTeamID="PWA5E9TQ59"

        updateScriptLog "Installing swiftDialog..."

        # Create temporary working directory
        workDirectory=$( /usr/bin/basename "$0" )
        tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

        # Download the installer package
        /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"

        # Verify the download
        teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

        # Install the package if Team ID validates
        if [[ "$expectedDialogTeamID" == "$teamID" ]]; then
            /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
            sleep 2
            dialogVersion=$( /usr/local/bin/dialog --version )
            updateScriptLog "swiftDialog version ${dialogVersion} installed; proceeding..."
        else
            # Display a so-called "simple" dialog if Team ID fails to validate
            osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Setup Your Mac: Error" buttons {"Close"} with icon caution'
            exit 1
        fi

        # Remove the temporary working directory when done
        /bin/rm -Rf "$tempDirectory"

    else

        dialogVersion=$(/usr/local/bin/dialog --version)    
        updateScriptLog "swiftDialog version ${dialogVersion} found..."

    fi   

}

# DockUtil Check
function dockutilCheck() {

    # Checking if Dockutil is installed
    if [[ -x "/usr/local/bin/dockutil" ]]; then
        updateScriptLog "dockutil is installed in /usr/local/bin"
        dockutil="/usr/local/bin/dockutil"
    else
        updateScriptLog "dockutil not installed in /usr/local/bin"
        updateScriptLog "installing dockutil"
        
        # Get the URL of the latest PKG From the Dialog GitHub repo
        dockutilURL=$(curl -s "https://api.github.com/repos/kcrawford/dockutil/releases/latest" | grep "https*.*pkg" | cut -d : -f 2,3 | tr -d \" | xargs curl -SL --output /tmp/dockutil.pkg)
        
        # Download the installer package
        /usr/bin/curl --location --silent "$dockutilURL" -o "tmp/dockutil.pkg"
        /usr/sbin/installer -pkg "tmp/dockutil.pkg" -target /
        dockutil="/usr/local/bin/dockutil"
    fi

}

# tmp Folder Check
function tmpFolderCheck() {

    # Checking if VectorWorks tmp folder already exists
    if [[ -f /tmp/VectorWorks ]];then
        rm -rf /tmp/VectorWorks
        updateScriptLog "Removed tmp folder"
    fi
}

# Variables Check
function variableChecks() {

    # Checking for empty variables
    if [[ "$YNAME" == "" ]]; then
        updateScriptLog "Missing variables, exiting..."
        exit 1
    fi

}

# PreCheck Function
function preChecks() {

    variableChecks
    logFileCheck
    tmpFolderCheck

    dialogCheck
    dockutilCheck

}

# Swift Dialog - Ask user if they want to uninstall the previous version
function uninstallAsk() {

    /usr/local/bin/dialog --height "180" \
    --title "VectorWorks 2025 already installed." \
    --message "VectorWorks install detected, Do you want to reinstall?." \
    --button1text "Yes" \
    --button2text "No" \
    --icon "https://euw2.ics.services.jamfcloud.com/icon/hash_933913ee4e03327be504fcf67441a1f6b22ec2d2c79a0f98ec7e9953fbdaef6a" \
    --messagefont "size=16" \
    --helpmessage "Please contact: **COMPANYsupport@COMPANY.com** if you require assistance." \
    --timer 900 | awk -F ' : ' '{print $NF}'

        returncode=$?

        case ${returncode} in

            0)  ## Process exit code 0 scenario here
                updateScriptLog "SWIFTDIALOG: ${loggedInUser} pressed yes;"
                uninstallStatus="Yes"
                ;;

            2) ## Process exit code 2 scenario here
                updateScriptLog "SWIFTDIALOG: ${loggedInUser} pressed no;"
                uninstallStatus="No"
                ;;
            
            *) ## Error occured
                updateScriptLog "SWIFTDIALOG: An error occured, exiting...;"
                exit 1
                ;;

        esac
        
}

# Uninstall VectorWorks
function uninstallVectorWorks() {
    updateScriptLog "Starting Vectorworks 2025 uninstallation..."

    # Quit Vectorworks if running
    app_name="Vectorworks 2025"
    if pgrep -x "$app_name" > /dev/null; then
        updateScriptLog "Closing Vectorworks 2025..."
        pkill -x "$app_name"
        sleep 2
    fi

    # Remove the main application
    updateScriptLog "Removing Vectorworks 2025 from Applications..."
    rm -rf "/Applications/Vectorworks 2025"

    # Remove support files in User Library
    updateScriptLog "Removing user library files..."
    rm -rf "$HOME/Library/Application Support/Vectorworks/2025"
    rm -rf "$HOME/Library/Preferences/net.nemetschek.vectorworks.2025.plist"
    rm -rf "$HOME/Library/Preferences/Vectorworks/2025"

    # Remove system-wide support files
    updateScriptLog "Removing system-wide files..."
    sudo rm -rf "/Library/Application Support/Vectorworks/2025"
    sudo rm -rf "/Library/Preferences/net.nemetschek.vectorworks.2025.plist"
    sudo rm -rf "/Library/Logs/Vectorworks/2025"

    # Remove cached files
    updateScriptLog "Removing cached files..."
    rm -rf "$HOME/Library/Caches/net.nemetschek.vectorworks.2025"
    sudo rm -rf "/Library/Caches/net.nemetschek.vectorworks.2025"

    # Remove license information (if needed)
    updateScriptLog "Removing license files..."
    rm -rf "$HOME/Library/Application Support/Vectorworks/2025/License"
    sudo rm -rf "/Library/Application Support/Vectorworks/2025/License"

    # Final cleanup
    updateScriptLog "Uninstallation complete."

}

# Ask the end user for the serial
function serialAskAndInstall() {

    captureSerial=$(/usr/local/bin/dialog --height "260" \
    --title "VectorWorks 2025 Serial Number Required." \
    --message "Please enter the Serial Number for VectorWorks 2025, then press OK to continue.  \n\nIf you dont know the Serial, please press help for contact details of how to retreive the serial." \
    --textfield "Serial Number",value="XXXXXX-XXXXXX-XXXXXX-XXXXXX",required,prompt="Enter 24 digit Serial Number",regex="^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$",regexerror="The Serial Number must be UPPERCASE and complte with hythons (-) every 6 Characters." \
    --button1text "OK" \
    --button2text "Cancel" \
    --icon "https://euw2.ics.services.jamfcloud.com/icon/hash_933913ee4e03327be504fcf67441a1f6b22ec2d2c79a0f98ec7e9953fbdaef6a" \
    --messagefont "size=13" \
    --helpmessage "Please contact: **COMPANYsupport@COMPANY.com** if you require assistance." \
    --timer 900 | awk -F ' : ' '{print $NF}')

    returncode=$?

        case ${returncode} in

            0)  ## Process exit code 0 scenario here
                updateScriptLog "SWIFTDIALOG: ${loggedInUser} entered the Serial and pressed OK;"

                SERIAL=$(echo $captureSerial)

                # Get LDF based on serial given
                case "$SERIAL" in
                    "XXXXXX-XXXXXX-XXXXXX-XXXXX1")
                        LDF="MK-XXXXX1"
                        ;;
                    "XXXXXX-XXXXXX-XXXXXX-XXXXX2")
                        LDF="MK-XXXXX2"
                        ;;
                    "XXXXXX-XXXXXX-XXXXXX-XXXXX3")
                        LDF="MK-XXXXX3"
                        ;;
                    "XXXXXX-XXXXXX-XXXXXX-XXXXX4")
                        LDF="MK-XXXXX4"
                        ;;
                    "XXXXXX-XXXXXX-XXXXXX-XXXXX5")
                        LDF="MK-XXXXX5"
                        ;;
                    *)
                        LDF=""
                        ;;
                esac

                # Check LDF status
                if [[ "$LDF" == "" ]]; then
                    updateScriptLog "Missing LDF, exiting..."
                    exit 2
                fi

                

                # Do the install using the provided variables
                /tmp/VectorWorks/Vectorworks\ "${YNAME}"\ Install\ Manager.app/Contents/Resources/cli.sh download --dest /tmp/VectorWorks/ --target Update0  >> "$commandLog"
                /tmp/VectorWorks/Vectorworks\ "${YNAME}"\ Install\ Manager.app/Contents/Resources/cli.sh install --installdir "/Applications/Vectorworks ${YNAME}" --serial "${SERIAL}" -i "/tmp/VectorWorks/Update0.vwim" --ldf /tmp/VectorWorks/VectorWorksLDFs/${LDF}.ldf --uid $myUid --gid $myGid >> "$commandLog"

                # Populate Dock
                if [[ -f "/usr/local/bin/dockutil" ]];then
                    /usr/local/bin/dockutil --add "/Applications/Vectorworks ${YNAME}/Vectorworks ${YNAME}.app" --label "Vectorworks ${YNAME}" $CurrentUserPlist
                else
                    updateScriptLog "dockutil not installed"
                fi
                ;;

            2)  ## Process exit code 2 scenario here
                updateScriptLog "SWIFTDIALOG: ${loggedInUser} clicked Cancel;"
                exit 2
                ;;

            3)  ## Process exit code 3 scenario here
                updateScriptLog "SWIFTDIALOG: ${loggedInUser} clicked ${infobuttontext};"
                ;;

            4)  ## Process exit code 4 scenario here
                updateScriptLog "SWIFTDIALOG: ${loggedInUser} allowed timer to expire, cancelled process;"
                ;;

            20) ## Process exit code 20 scenario here
                updateScriptLog "SWIFTDIALOG: ${loggedInUser} had Do Not Disturb enabled"
                ;;

            *)  ## Catch all processing
                updateScriptLog "SWIFTDIALOG: Something else happened; Exit code: ${returncode};"
                ;;

        esac

}

function main() {

    preChecks

    # Print Variables
    updateScriptLog ""
    updateScriptLog "STARTING VECTORWORKS INSTALLATION..."
    updateScriptLog "Supplied Variables are..."
    updateScriptLog "Version of VectorWorks: $YNAME"
    updateScriptLog "Serial Number: $SERIAL"
    updateScriptLog "LDF: $LDF"
    updateScriptLog "Logged in user: $loggedInUser"
    updateScriptLog "$loggedInUser Dock plist location: $loggedInUserPlist"
    updateScriptLog "$loggedInUser GID: $myGid"
    updateScriptLog "$loggedInUser UID: $myUid"
    
    # Check for and prompt to uninstall if installed
    if [[ -d "/Applications/Vectorworks 2025" ]];then
        updateScriptLog "VectorWorks 2025 install detected, asking user if they want to uninstall"
        uninstallAsk
            if [[ $uninstallStatus == "Yes" ]]; then
                updateScriptLog "User said yes to uninstall"
                uninstallVectorWorks
                serialAskAndInstall
            elif [[ $uninstallStatus == "No" ]]; then
                updateScriptLog "User said no to uninstall... exiting"
                exit 2
            fi
    else 
        updateScriptLog "VectorWorks 2025 is not detected, proceeding to ask user for serial and install"
        serialAskAndInstall

    fi
}



## Main Part
main

exit 0
