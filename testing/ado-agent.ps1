New-Item "C:\agent" -itemType Directory
cd "C:\agent"
$url = "https://dev.azure.com/YOUR_ORG"
$token = "PAT_TOKEN"
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$token"))

$package = Invoke-RestMethod "$url/_apis/distributedtask/packages/agent?platform=win-x64&$`top=1" -Headers @{Authorization = "Basic $auth"}

$fileName = $package.value[0].fileName;
$downloadUrl = $package.value[0].downloadUrl;
    

Invoke-WebRequest -UseBasicParsing $downloadUrl -OutFile agent.zip
Expand-Archive -Force agent.zip -DestinationPath .
Remove-Item -Force agent.zip


.\config.cmd --unattended --replace --acceptTeeEula --work work --url https://dev.azure.com/YOUR_ORG --pool YOUR_POOL_NAME --auth pat --token $token --runAsService --runAsAutoLogon --windowsLogonAccount USER --windowsLogonPassword USER_PASSWORD
.\run.cmd
