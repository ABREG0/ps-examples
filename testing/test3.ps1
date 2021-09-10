# cabrego - 20210412
# Force use of TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Firewall
netsh advfirewall firewall add rule name="http" dir=in action=allow protocol=TCP localport=80

write-host "successful"

# Folders
New-Item -ItemType Directory c:\temp1
New-Item -ItemType Directory c:\music1
