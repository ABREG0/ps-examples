# cabrego 2018
# Add restriction rules to function apps and web apps. 

Disconnect-AzAccount -ContextName 'myTenant' | Out-Null
get-azcontext -ListAvailable | ForEach-Object {$_ | remove-azcontext -Force -Verbose} #remove all connected content

Try{
#connect to azure and setup context name
$TenantID = ''

$ConnectToTentant = Connect-AzAccount -Tenant $TenantID -ContextName 'myTenant' -Force -ErrorAction Stop 

#Select subscription to build
$GetSubscriptions = Get-AzSubscription | Where-Object {($_.state -eq 'enabled') } | Out-GridView -Title "Select Subscription" -PassThru #-OutputMode Single

}
catch{

Write-warning "Error when trying to connect to tenant...`n"

$_ ;

exit 
#$_.Exception.Message
} 

foreach($Subscription in $GetSubscriptions)
{
   Try{
	   #getting subscription object to set context
	   $SubscriptionObj = get-azsubscription -su -SubscriptionId $Subscription.Id -ErrorAction Stop  | Where-Object {($_.state -eq 'enabled') }

	   #Set context for subscription being built
	   $SubscriptionContextReturn = Set-AzContext -Subscription $SubscriptionObj.id
		
   }
    catch [Exception]{ 

        Write-warning "Error Message: `n$_ "

        $_

    }

#region NewRules - none RFC1918
$NewIpRules = @(
  @{
    ipAddress = "xx.xx.0.0/23"; 
    action = "Allow";
    priority = "112";
    name = "my ARIN";
    description = "xx.xx.0.0/23";

  },
	@{
    ipAddress = "xx.xx.xx.xx/32"; 
    action = "Allow";
    priority = "120";
    name = "IPs for my";
    description = "xx.xx.xx.xx/32";

  },
 @{
   #subnetID
    vnetSubnetResourceid = '/subscriptions/{subscription_id}/resourceGroups/{rgName}/providers/Microsoft.Network/virtualNetworks/{vnetName}/subnets/{subnetName}'
    action = "Allow";
    priority = "111";
    name = "{subnetName}-Allow";
    description = "Allow";
  }
	
)
#endregion newrules

#region SCMRules - none RFC1918
$SCMIpRules = @(
    @{
        ipAddress   = "xx.xx.xx.xx/32";
        action      = "Allow";
        priority    = "300";
        name        = "Cloud VPN";
        description = "my VPN Connections";
    },
	@{
        ipAddress   = "xx.xx.xx.xx/32";
        action      = "Allow";
        priority    = "300";
        name        = "Cloud VPN";
        description = "my VPN Connections";
    }
)

#endregion SCMRules
$MYsn = @(
	@{
	vnetSubnetResourceid = '/subscriptions/{subscription_id}/resourceGroups/{rgName}/providers/Microsoft.Network/virtualNetworks/{vnetName}/subnets/{subnetName}'
  action = "Allow";
  priority = "110";
  name = "MY-FunctionApp-Allow";
  description = "MY to Function App communication";
  }
)

$NewIpRules += $SCMIpRules
$NewIpRules += $MYsn

    #grab the latest available api version
    $APIVersion = ((Get-AzResourceProvider -ProviderNamespace Microsoft.Web).ResourceTypes | Where-Object ResourceTypeName -eq sites).ApiVersions[0]

    $GetWebApps = ''; $GetWebApps = Get-AzWebApp | Select-Object name,ResourceGroup,DefaultHostName,kind,location,PossibleOutboundIpAddresses,serverfarmid | Out-GridView -PassThru

	foreach($webapp in $GetWebApps)
	{
		$ASPname = ''; $ASPname = ([regex]::matches(($webapp.ServerFarmId -split ','), '[^/]+$').value)

		Write-Host "ASP Name: $ASPname `n"
		$WebAppConfig = Get-AzResource -Resourcename $webapp.name -ResourceType 'Microsoft.Web/sites/config' -ResourceGroupName $webapp.ResourceGroup -ApiVersion $APIVersion

		$GetSiteConfigAuth = '';
		$GetSiteConfigAuth = Invoke-AzResourceAction -ResourceGroupName $webapp.ResourceGroup -ResourceType Microsoft.Web/sites/config -ResourceName "$($webapp.name)/authsettings" -Action list -ApiVersion $APIVersion -Force
		
		Write-Host "AuthN enabled? $($GetSiteConfigAuth.properties.Enabled.ToString())"
		
		if($GetSiteConfigAuth.properties.Enabled){
		
			Write-Host "AuthN is enabled: $($GetSiteConfigAuth.properties.Enabled.ToString())"

		 	}
		 	 else{

			 Write-Host "NoProviderSet and AuthN is NOT Enabled: $($GetSiteConfigAuth.properties.Enabled.ToString())"

				foreach ($NewIpRule in $NewIpRules) {
				Write-Host "`n Adding Restriction Rules to WebApp: $($webapp.name)`n" 
				$WebAppConfig.Properties.ipSecurityRestrictions += $NewIpRule
				$WebAppConfig.Properties.scmipSecurityRestrictions += $NewIpRule

			}
			
			Set-AzResource -ResourceId $WebAppConfig.ResourceId -Properties $WebAppConfig.Properties -ApiVersion $APIVersion -Force
		
		}

	}


}
Disconnect-AzAccount | Out-Null #-ContextName 'myTenant'
Write-Output 'removing all current contexts'
get-azcontext -ListAvailable | ForEach-Object {$_ | remove-azcontext -Force -Verbose | Out-Null} #remove all connected content
