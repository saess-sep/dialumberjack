set DialogText to "There is a pending update.  Would you like to snooze this notification for 20 minutes, delay for a set amount of time, or install the update now?"
set DialogTitle to "Pending Update"
set DialogOptions to {"Snooze", "Delay", "Update"}

set DelayOptions to {"1 Hour", "2 Hours", "3 Hours", "Tonight", "Tomorrow"}

set SadnessTimer to 45
set NotSnooze to false

repeat until NotSnooze
	set DialogResult to button returned of (display dialog DialogText with title DialogTitle buttons DialogOptions giving up after SadnessTimer)
	if DialogResult is "Snooze" then
		DialogResult
		delay SadnessTimer
	else if DialogResult is "Update" then
		set NotSnooze to true
		set Action to "update"
		Action
	else if DialogResult is "Delay" then
		set NotSnooze to true
		set DelayResult to choose from list DelayOptions with prompt "How long would you like to delay the update?"
		if DelayResult is "Tomorrow" then
			set Action to "skip"
			Action
		else if DelayResult is "Tonight" then
			set Action to "schedule"
			Action
		else if DelayResult is "1 Hours" then
			set Action to "wait1"
			Action
		else if DelayResult is "2 Hours" then
			set Action to "wait2"
			Action
		else if DelayResult is "3 Hours" then
			set Action to "wait3"
			Action
		end if
	end if
end repeat