
param (
    [parameter(Mandatory = $true)]
    [System.String]
    $folderName1,

    [parameter(Mandatory = $true)]
    [System.String]
    $folderName2

)

# Force use of TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Firewall
netsh advfirewall firewall add rule name="http" dir=in action=allow protocol=TCP localport=80

# Folders
New-Item -ItemType Directory c:\$folderName1
New-Item -ItemType Directory c:\$folderName2
