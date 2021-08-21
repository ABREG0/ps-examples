# cabrego 2021
# Requires PowerShell core and lastest Az module 

# add your tenant id here... 
$TenantID = ''

# Disconnect exiting connections and clearing contexts.
Write-Output "Clearing existing Azure connection `n"
Disconnect-AzAccount -ContextName 'myCont' | Out-Null

Write-Output "Clearing existing Azure context `n"
get-azcontext -ListAvailable | ForEach-Object { $_ | remove-azcontext -Force -Verbose | Out-Null } #remove all connected content

Write-Output "`nClearing of existing connection and context completed. `n"

$scriptPath = $scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

Try {
    #Connect-AzAd
    #connect to azure and setup context name

    $ConnectToTentant = Connect-AzAccount -Tenant $TenantID -ContextName 'MGMTenant' -Force -ErrorAction Stop 

    #$ConnectToTentant.Context

    #Select subscription to build
    $GetSubscriptions = Get-AzSubscription |  Out-GridView -Title "Select Subscription to build" -PassThru 

}
catch {

    Write-warning "Error When trying to connct to tenant...`n"

    $_ ;

    exit 
    #$_.Exception.Message
} 

$HTRoleAssignments = ''; $HTRoleAssignments = @()

foreach ($GetSubscription in $GetSubscriptions) {

    Try {
        #getting subscription object to set context
        $GetSubscriptionObj = get-azsubscription -SubscriptionId $GetSubscription.Id -ErrorAction Stop  | Where-Object { ($_.state -eq 'enabled') }

        #Set context for subscription being built
        $SubscriptionContextReturn = Set-AzContext -Subscription $GetSubscriptionObj.id
		 
    }
	   catch [Exception] { 

        Write-warning "Error Message: `n$_ "

        $_

    }
    
		Write-Host "Subscription Name: $($GetSubscriptionObj.Name) `n"
		$Assignments = ''; $Assignments = Get-AzRoleAssignment #| ? {($_.RoleDefinitionName -eq 'owner') -or ($_.RoleDefinitionName -eq 'Contributor')} #-RoleDefinitionName "owner"
		
		foreach ($Assignment in $Assignments){
			#build web hash table PSObject
			if($null -ne $Assignment.DisplayName){
				$groupMembers = '';
                
                Write-Host $_.Exception.Message
                if($Assignment.ObjectType -eq 'Group'){
                    try{
                        $Assignment.DisplayName
                        $members = '';
                        [array]$members = Get-AzAdGroup -DisplayName $($Assignment.DisplayName) | Get-AzAdGroupMember
                        $groupMembers = $members.DisplayName -join ';'
                        
                        }
                        catch{
                        Write-Host $_.Exception.Message
                        }
                    }
                     else{
                        $Assignment.DisplayName
                         $groupMembers = '' #empty if is not a group
                     }
						
                }
                
			$RolesAssignments = '';	$RolesAssignments = new-object PSObject 
			$RolesAssignments | add-member -membertype NoteProperty -name "Subscription" -Value $GetSubscriptionObj.Name
            $RolesAssignments | add-member -membertype NoteProperty -name "DisplayName" -Value $Assignment.DisplayName
            $RolesAssignments | add-member -membertype NoteProperty -name "Scope" -Value $Assignment.scope 
			$RolesAssignments | add-member -membertype NoteProperty -name "GroupMembers" -Value $groupMembers
	    	$RolesAssignments | add-member -membertype NoteProperty -name "RoleDefinitionName" -Value $Assignment.RoleDefinitionName
			$RolesAssignments | add-member -membertype NoteProperty -name "SignInName" -Value $Assignment.SignInName
			$RolesAssignments | add-member -membertype NoteProperty -name "ObjectType" -Value $Assignment.ObjectType

			$HTRoleAssignments += $RolesAssignments
			
		}
		
}

$HTRoleAssignments | ConvertTo-Csv -NoTypeInformation | Out-File "$($scriptPath)\AllRoleAssigned$(get-date -f yyyyddmm-hhmmss).csv" -NoClobber -Append
