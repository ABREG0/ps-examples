
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

# choco install terraform --version=1.4.0 -y --force --force-dependencies # no yes in choco
    $Url = 'https://releases.hashicorp.com/terraform/1.4.0' #'https://www.terraform.io/downloads.html'
    
    try {

      $tfVersion = @(terraform -v) | Where-Object{$_ -match 'terraform'} | ForEach-Object{"$($_ -replace 'terraform v')"}

      #$terraformPath = $ENV:Path -split ';' | Where-Object { $_ -match 'terraform'}

    }
    catch {
        $tfVersion = $null
      #$terraformPath = $null
    }

    if(($null -eq $terraformPath) -and ($null -eq $tfVersion)){

        $terraformPath = 'C:\Terraform\'

        $envRegpath = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment'

        $PathString = (Get-ItemProperty -Path $envRegpath -Name PATH).Path

        $PathString += ";$($terraformPath)"

        $null = New-Item -Path $($terraformPath) -ItemType Directory -Force 

        $source = (Invoke-WebRequest -Uri $url -UseBasicParsing).links.href | Where-Object {$_ -match 'windows_amd64'}

        $destination = "$env:TEMP\$(Split-Path -Path $source -Leaf)"

        Invoke-WebRequest -Uri $source -OutFile $destination -UseBasicParsing
        
        Expand-Archive -Path $destination -DestinationPath $terraformPath -Force

        Remove-Item -Path $destination -Force

        Set-ItemProperty -Path $envRegpath -Name PATH -Value $PathString -ErrorAction SilentlyContinue

        $ENV:Path += ";$($terraformPath)"
      }
      else{

        Write-Host " Terraform is Installed... version: $($tfVersion)" -ForegroundColor Green
      }
