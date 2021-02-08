#!/bin/bash/

###############################################################
#Config                                                       #
###############################################################
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

#Argument Passing
##Shift arguments for Jamf
if [[ $1 == "/" ]]; then
    shift 3
fi
##Jamf custom event name to call on success (the policy you actually want to run) (string)
JamfEventSuccess = $1
##Jamf custom event name to call on a snooze (should be the event name of this policy) (string)
JamfEventSnooze = $2
##Friendly name of update (string)
FriendlyName = $3
##Can the update be delayed? (bool)
CanDelayBool = $4
if [[ CanDelayBool ]]; then
    CanDelayText = "can"
elif [[ !CanDelayBool ]]; then
    CanDelayText = "cannot"
##Time in seconds before the dialog exits with an error
SadnessTimer = $5

#Fixed config items
##Amount of time to snooze in seconds
SnoozeNumber = 600
##Options for initial pop-up dialog
DialogText = "There is a pending update for $FriendlyName.  Would you like to update now, snooze this notification for $SnoozeNumber minutes, or schedule another time for this update?"
DialogTitle = "Update Pending"
if [[ CanDelayBool ]]; then
    DialogOptions = "{\"Update Now\", \"Snooze\", \"Schedule\"}"
elif [[ CanDelayBool ]]; then
    DialogOptions = "{\"Update Now\", \"Snooze\"}"
##Options for delay picking list
DelayPrompt = "When would you like to schedule the update"
DelayOptions = "{\"1 Hour\", \"2 Hours\", \"3 Hours\", \"Tonight\", \"Tomorrow\"}"

###############################################################
#Functions                                                    #
###############################################################

#Runs commands as currently logged in user
#If not used, command runs as root (thanks, Jamf!)
runAsUser() {  
  if [ "$currentUser" != "loginwindow" ]; then
    launchctl asuser "$uid" sudo -u "$currentUser" "$@"
  else
    echo "no user logged in"
    # uncomment the exit command
    # to make the function exit with an error when no user is logged in
    # exit 1
  fi
}

#Check for Do-Not-Disturb assertions
checkForDisplaySleepAssertions() {
    Assertions="$(/usr/bin/pmset -g assertions | /usr/bin/awk '/NoDisplaySleepAssertion | PreventUserIdleDisplaySleep/ && match($0,/\(.+\)/) && ! /coreaudiod/ {gsub(/^\ +/,"",$0); print};')"
    
    # There are multiple types of power assertions an app can assert.
    # These specifically tend to be used when an app wants to try and prevent the OS from going to display sleep.
    # Scenarios where an app may not want to have the display going to sleep include, but are not limited to:
    #   Presentation (KeyNote, PowerPoint)
    #   Web conference software (Zoom, Webex)
    #   Screen sharing session
    # Apps have to make the assertion and therefore it's possible some apps may not get captured.
    # Some assertions can be found here: https://developer.apple.com/documentation/iokit/iopmlib_h/iopmassertiontypes
    if [[ "$Assertions" ]]; then
        echo "The following display-related power assertions have been detected:"
        echo "$Assertions"
        echo "Exiting script to avoid disrupting user while these power assertions are active."
        
        exit 10
    fi
}

###############################################################
#Actual Script                                                #
###############################################################
#First, check that do not disturb is off.  If it's on, fail (so JAMF will retry)
checkForDisplaySleepAssertions

#Next, display the initial dialog
DialogResult=$(runAsUser osascript -e "button returned of (display dialog $DialogText with title $DialogTitle buttons $DialogOptions giving up after $SadnessTimer)")
#If the user selects 'Update', call the custom Jamf policy trigger
if [[ DialogResult == "Update Now" ]]; then
    echo "Running update $FriendlyName via $JamfEventSuccess"
    jamf policy --event $JamfEventSuccess
    exit 0
elif [[ DialogResult == "Snooze" ]]; then
    #If the user selects 'Snooze', spawn a shell to call this policy again
    echo "Snoozing update for $SnoozeNumber"
    MAKENEWSHELLCOMMAND sleep $SnoozeNumber && jamf policy --event $JamfEventSnooze
    exit 0
elif [[ DialogResult == "Delay" ]]; then
    #if the user selects 'Schedule' then offer a list of options for scheduling
    #then snooze for the appropriate amount of time
    #or call a shell for a scheduled time (e.g.'Tonight')
    DelayResult=$(runAsUser osascript -e "choose from list $DelayOptions with prompt $DelayPrompt")
    #Jamf will run this task daily, so Tomorrow just exits
    if [[ DelayResult == "Tomorrow" ]]; then
        echo "User delayed until Tomorrow"
        exit 0
    #if the user wants to run the update tonight
    elif [[ DelayResult == "Tonight" ]]; then
        #first check if it's already after five, interogate user for what they want
        if [[ TIME-IS-AFTER-FIVE ]]; then
            DISPLAYDIALOG "IT'S ALREADY TONIGHT, WHAT DO?"
        #if it's not night time, schedule the update to run automatically after 6pm local
        else
            MAKENEWSHELLCOMMAND SCHEDULECOMMAND LOCALTIME-AFTER-6PM && jamf policy --event $JamfEventSuccess
            echo "User scheduled update for tonight"
            exit 0
        fi
    elif [[ $(echo $DelayResult | grep -e "Hour") ]]; then
        CONVERT WORD-NUMBER-HOURS INTO INTEGER-SECONDS
        DelayHours=$( echo $DelayResult | tr -d 'a-zA-Z')
        DelaySeconds=$(expr $DelayHours \* 60)
        MAKENEWSHELLCOMMAND sleep $DelaySeconds && jamf policy --event $JamfEventSnooze
    fi
fi


#Notes
#MAKENEWSHELLCOMMAND IS PROBABLY & AT THE END OF A LINE