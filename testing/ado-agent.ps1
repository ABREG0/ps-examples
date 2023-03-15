
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

if (test-path "c:\agent")
{
    Remove-Item -Path "c:\agent" -Force -Confirm:$false -Recurse
}

new-item -ItemType Directory -Force -Path "c:\agent" | select name

set-location "c:\agent"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$package = 'https://vstsagentpackage.azureedge.net/agent/3.217.1/vsts-agent-win-x64-3.217.1.zip'

write-host "agent url: [$($package)]"

Invoke-WebRequest $package -Out agent.zip

Expand-Archive -Path agent.zip -DestinationPath $PWD

.\config.cmd --unattended --work "work" --agent "$($ComputerName)" --replace --url "$($adoOrgUrl)" --pool "$($poolName)" --auth pat --token $token --runAsService --windowsLogonAccount "NT AUTHORITY\SYSTEM"
.\run.cmd
