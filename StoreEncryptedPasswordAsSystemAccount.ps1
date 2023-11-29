<#

    AUTHOR:         Keith Francis updated Mahir Mujkanovic @ Networkantics
    Description:    This script creates a scheduled task under the system account and runs a command to create a text file with an encrypted password.
                    Since this password is encrypted using the system account, only tasks run under the System account that use this text file for the
                    password will be able to decrypt this password. No other account can decrypt it. This way, the password is stored securely and not
                    in plain text in a powershell script. The encrypted password can be used to, for example, authenticate an account that may be
                    used in a PS script. I could not find another way to run a command under the system account in PowerShell so creating
                    a scheduled task and running it there under the system account will have to do

#>

#Task name. Call it whatever you want
$taskName = "Create Secure Azure APP ClientSecret"

#This is the path and name where the encrypted password will be stored in a text file
$clientSecretFolderPath = "C:\Program Files\NetworkAnticsTools\"
$clientSecretFileName = "clientSecret.txt"
$clientSecretFilePath = Join-Path -Path $clientSecretFolderPath -ChildPath $clientSecretFileName

#Create the filePath if it does not exist
if(!(Test-Path $clientSecretFolderPath)){ New-Item -ItemType Directory -Force -Path $clientSecretFolderPath }


#This is the password you are trying to encrypt. Doing -AsSecureString so that it doesn't show the password when you type it
$clientSecretSS = Read-Host -Prompt "Enter Client Secret" -AsSecureString #This is where you enter the ClientSecret

#Convert the password back to plain text
$clientSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientSecretSS))

#Remove task with the name "Create Secure Azure APP ClientSecret" if it already exists
$task = Get-ScheduledTask | Where-Object {$_.TaskName -like $taskName}
if (![string]::IsNullOrWhiteSpace($task))
{
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

#Create the action for the scheduled task. It will run powershell and execute the command specified below
$action = New-ScheduledTaskAction -Execute 'Powershell.exe' `
          -Argument "-command &{'$clientSecret' | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File -FilePath `'$clientSecretFilePath`' -Encoding utf32}"

#Register Scheduled task and then run it once to create the text file with the encrypted password
Register-ScheduledTask -Action $action -TaskName $taskName -Description "Creates a text file with the encrypted Azure App Client Secret" -User "System" -RunLevel Highest
Start-ScheduledTask -TaskName $taskName

#Remove the task after it is run
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false

