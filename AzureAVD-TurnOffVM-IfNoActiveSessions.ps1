#######################################
#
# Mahir Mujkanovic @ networkantics.com - May 2023 v: 1.3
# 
# The Script is designed to be run as a scheduled task activated on StartUp and by the LogOff event EventID=4647, Though it can be run as time scheduled also.
# The Script will query user sessions and if no active sessions are present
# the Script will set the flag "userConnectionsActive" (in registry) to "0" and sleep for 15 minutes 
# the Script will query user sessions again, if there are still no active users and the userConnectionsActive flag is still "0" the script will Deallocate the Azure VM
# if the script realizes there are active connections it will set the "userConnectionsActive" to 1 and end itself
#
########################################

# Encrypt and store Client Secret
# Make sure to do this under context of user profile the script will be run under
# We do not use this at NetworkAntics for our Azure AVD setup. We run scheduled tasks under System user
# Procedure and script defined on how to store encrypted secret under System user can be found in the docs
<######

$clientSecretFilePath="C:\Program Files\NetworkAnticsTools\clientSecret.txt"
$Secure = Read-Host -AsSecureString  #This is where you add the ClientSecret
$Encrypted = ConvertFrom-SecureString -SecureString $Secure
Set-Content -Value $Encrypted -Path $clientSecretFilePath

######>

####
# Variables START
####

#Subscription Id.
$subscriptionId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
 
#Tenant Id.
$tenantId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" #Tenant GUID or <tenantname>.onmicrosoft.com
 
#Client Id.
$clientId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" #the GUID of your app.
 
# Target Resource Group name
$resourceGroup = "<Target-Resource-Group-Name>"

# Target VM name
$vmName = "<Target-VM-Name>"

#Client Secret file path
$clientSecretFilePath="C:\Program Files\NetworkAnticsTools\clientSecret.txt"
#Client Secret.
$clientSecretAsSecureString = Get-Content $clientSecretFilePath | ConvertTo-SecureString
$clientSecret = [System.Net.NetworkCredential]::new("", $clientSecretAsSecureString).Password



####
# Variables END
####

####
# Constants definitions START
####

$waitTime=900  # amount of time, in seconds, the script will sleep before it checks the second time are there any active connections and if not it will shutdown the OS
$registryPath = "HKLM:\Software\NetworkAntics"
$registryUserConnectionsActiveProperty = "userConnectionsActive"

####
# Constants definitions END
####


####
# FUNCTION DEFINITIONS START
####

function Test-RegistryPropertyExistence
{
    param 
    (
        [parameter(Mandatory=$true)][string][ValidateNotNullOrEmpty()]$Path,
	    [parameter(Mandatory=$true)][string][ValidateNotNullOrEmpty()]$PropertyName
    )
    try
    {
        $targetProperty=$null
        $targetProperty=Get-ItemProperty -Path $Path -Name $PropertyName -ErrorAction Stop
                
        if($targetProperty){return $true}
        else{return $false}
    }
    catch
    {
        return $false
    }

}

function Deallocate-AzureVM
{
    param 
    (
        [parameter(Mandatory=$true)][string][ValidateNotNullOrEmpty()]$SubscriptionId,
	    [parameter(Mandatory=$true)][string][ValidateNotNullOrEmpty()]$TenantId,
        [parameter(Mandatory=$true)][string][ValidateNotNullOrEmpty()]$ClientId,
        [parameter(Mandatory=$true)][string][ValidateNotNullOrEmpty()]$ClientSecret,
        [parameter(Mandatory=$true)][string][ValidateNotNullOrEmpty()]$ResourceGroup,
        [parameter(Mandatory=$true)][string][ValidateNotNullOrEmpty()]$VmName
    )

    # API Access
    $Resource = "https://management.azure.com/"
    $RequestAccessTokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/token"
    $Body = "grant_type=client_credentials&client_id=$ClientId&client_secret=$ClientSecret&resource=$Resource"

    # Get Access Token
    $AccessToken = Invoke-RestMethod -Method Post -Uri $RequestAccessTokenUri -Body $body -ContentType 'application/x-www-form-urlencoded'


    # Stop Azure Virtual Machines
    #$VMApiURI_STOP = "https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Compute/virtualMachines/{vmName}/deallocate?api-version=2022-11-01"
    $VMApiURI_STOP = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Compute/virtualMachines/$VmName/deallocate?api-version=2022-11-01"
    #$VMApiURI_START = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Compute/virtualMachines/$vmName/start?api-version=2022-11-01"
     
    # Format Header
    $Headers = @{}
    $Headers.Add("Authorization","$($AccessToken.token_type) "+ " " + "$($AccessToken.access_token)")
     
    #Invoke REST API
    Invoke-RestMethod -Method POST -Uri $VMApiURI_STOP -Headers $Headers 

}

## Get Remote Sessions
function GetRemoteSessions
{
    $quserResult = New-Object -TypeName 'System.Collections.ArrayList';
    $queryAllConnections=(((quser) -replace '^>', '') -replace '\s{2,}', ',').Trim() | ForEach-Object {
        if($_.Split(',').Count -eq 5) {
            Write-Output ($_-replace '(^[^,]+)', '$1,')
        } else{
            Write-Output $_}
    } | ConvertFrom-Csv

    foreach($userSession in $queryAllConnections)
    {
        if($userSession.SESSIONNAME -like "rdp*"){
            $quserResult.Add($userSession) >$null
        }
            
        
    }

    return , $quserResult
}

####
# FUNCTION DEFINITIONS END
####



# Make sure NetworkAntics registry directory is present
if(!(Test-Path $registryPath))
{
    New-Item -Path $registryPath -ItemType Directory
}

#query user sessions 
$quserResult = GetRemoteSessions

# if no active sessions
if($quserResult.Count -lt 1)
{

    # check if the userConnectionsActive property is present if not create it with value of 0 or if existent set it to the value of 0 
    if(!(Test-RegistryPropertyExistence -Path $registryPath -PropertyName $registryUserConnectionsActiveProperty))
    {
        New-ItemProperty -Path $registryPath -Name $registryUserConnectionsActiveProperty -Value 0 -PropertyType DWORD -Force | Out-Null

    }
    else
    {
        Set-ItemProperty -Path $registryPath -Name $registryUserConnectionsActiveProperty -Value 0
    }
}
else # if there are active sessions
{
    # check if the userConnectionsActive property is present if not create it with value of 1 or if existent set it to the value of 1 
    if(!(Test-RegistryPropertyExistence -Path $registryPath -PropertyName $registryUserConnectionsActiveProperty))
    {
        New-ItemProperty -Path $registryPath -Name $registryUserConnectionsActiveProperty -Value 1 -PropertyType DWORD -Force | Out-Null

    }
    else
    {
        Set-ItemProperty -Path $registryPath -Name $registryUserConnectionsActiveProperty -Value 1
    }

    exit
}

#sleep for designated amount of time
Start-Sleep -Seconds $waitTime 


#query user sessions again
$quserResult = GetRemoteSessions

#if no active sessions
if($quserResult.Count -lt 1)
{
    if(!(Get-ItemPropertyValue -Path $registryPath -Name $registryUserConnectionsActiveProperty -ErrorAction Stop))
    {
        Deallocate-AzureVM -SubscriptionId $subscriptionId -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret -ResourceGroup $resourceGroup -VmName $vmName
    }

}
else
{
    Set-ItemProperty -Path $registryPath -Name $registryUserConnectionsActiveProperty -Value 1
}

