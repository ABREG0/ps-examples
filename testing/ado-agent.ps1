
[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $poolName,
    [Parameter()]
    [string]
    $adoOrgUrl,
    [Parameter()]
    [string]
    $token,
    [Parameter()]
    [string]
    $ComputerName
)

write-host '#################################################'
write-host "pool: [$($poolName)] uri: [$($adoOrgUrl)] token: [$($token)] computer: [$($ComputerName)]"
write-host '#################################################'

New-Item "C:\agent" -itemType Directory

Set-Location "C:\agent"


$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$token"))

$package = Invoke-RestMethod "$($adoOrgUrl)/_apis/distributedtask/packages/agent?platform=win-x64&$`top=1" -Headers @{Authorization = "Basic $auth"}

$fileName = $package.value[0].fileName;
$downloadUrl = $package.value[0].downloadUrl;
    

Invoke-WebRequest -UseBasicParsing $downloadUrl -OutFile agent.zip
Expand-Archive -Force agent.zip -DestinationPath .
Remove-Item -Force agent.zip


.\config.cmd --agetn $ComputerName --unattended --replace --acceptTeeEula --work work --url $adoOrgUrl --pool $poolName --auth pat --token $token --runAsService
.\run.cmd
