
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

new-item -ItemType Directory -Force -Path "c:\agent"

set-location "c:\agent"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$wr = Invoke-WebRequest 'https://api.github.com/repos/Microsoft/azure-pipelines-agent/releases/latest'
write-host "wr url: [$($wr)]"

write-host "$tag is the latest version"
$package = 'https://vstsagentpackage.azureedge.net/agent/2.217.2/vsts-agent-win-x64-2.217.2.zip'

write-host "agent url: [$($package)]"

Invoke-WebRequest $package -Out agent.zip

Expand-Archive -Path agent.zip -DestinationPath $PWD

.\config.cmd --agetn $ComputerName --unattended --replace --acceptTeeEula --work work --url $adoOrgUrl --pool $poolName --auth pat --token $token --runAsService
.\run.cmd
