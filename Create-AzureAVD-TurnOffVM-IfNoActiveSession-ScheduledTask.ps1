####
#
# Mahir Mujkanovic @ Networkantics.com v: 1.0 - May 2023 
#
####

$targetScriptFilePath = '"C:\Program Files\NetworkAnticsTools\AzureAVD-TurnOffVM-IfNoActiveSessions.ps1"'
$taskName="TurnOffVM-IfNoActiveSessions"
$tasksFolderName="NetworkAntics"
$newTaskPath= Join-Path -Path "\" -ChildPath $tasksFolderName


# create the NetworkAntics Tasks folder

$scheduleObject = New-Object -ComObject schedule.service
$scheduleObject.connect()
$rootFolder = $scheduleObject.GetFolder("\")
$rootFolder.CreateFolder($tasksFolderName) 



# create list of triggers
$triggers = @()

# create TaskEventTrigger
$CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
$triggerOnEvent = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
$triggerOnEvent.Subscription = 
@"
<QueryList><Query Id="0" Path="Security"><Select Path="Security">*[System[Provider[@Name='Microsoft-Windows-Security-Auditing'] and (EventID=4647)]]</Select></Query></QueryList>
"@

#Creating Task 
$TaskAction = New-ScheduledTaskAction `
                    -Execute 'PowerShell.exe' `
                    -Argument "-NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -File $targetScriptFilePath"

$triggerOnEvent.Enabled = $True 

$triggers += $triggerOnEvent

$triggerOnStartup = New-JobTrigger -AtStartup -RandomDelay 00:03:00
$triggers += $triggerOnStartup



$TaskPrinciple = New-ScheduledTaskPrincipal `
                    -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$newTaskSettings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -Compatibility Win8 -MultipleInstances StopExisting -WakeToRun -ExecutionTimeLimit (New-TimeSpan -hours 1)
# create task
$User='Nt Authority\System'
$Action=New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -File $targetScriptFilePath"
Register-ScheduledTask -TaskName $taskName -TaskPath $newTaskPath -Trigger $triggers -User $User -Action $Action -RunLevel Highest -Force `
                        -Settings $newTaskSettings `
                        -Description "This task wil fire on Startup and on Event ID: 4647 and execute the script C:\Program Files\NetworkAnticsTools\AzureAVD-TurnOffVM-IfNoActiveSessions.ps1" 

