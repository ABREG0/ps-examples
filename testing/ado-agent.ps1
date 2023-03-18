
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

.\config.cmd --unattended --url "$($adoOrgUrl)" --pool "$($poolName)" --work "work" --agent "$($ComputerName)" --replace --auth pat --token $token --runAsService --windowsLogonAccount 'NT AUTHORITY\NETWORK SERVICE'

write-host "Check if PS was launched as admin..." -ForegroundColor Yellow
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{  
  $arguments = $SCRIPT:MyInvocation.MyCommand.Path 

  write-host "check if PS was launched as admin... re-launching the script:  $($arguments) " -ForegroundColor Red
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  
  Break
} 
 else{
    Write-Host "PowerShell was Launched as Admin... " -ForegroundColor Green
 }

 $TLS12Protocol = [System.Net.SecurityProtocolType] 'Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $TLS12Protocol

Set-ExecutionPolicy Bypass -Scope Process -Force;

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; 

Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))


choco install powershell-core --version=7.2.1 -y --force --force-dependencies
    
choco install azure-cli -y --force --force-dependencies

choco install git -y --force --force-dependencies

choco install terraform --version=1.4.0 -y --force --force-dependencies
