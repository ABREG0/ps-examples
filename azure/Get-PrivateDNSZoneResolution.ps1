# Requires -Modules Az.PrivateDns, # infoblox DNS servers nonprod 10.208.180.39

<#
.SYNOPSIS
    Queries all private DNS zones in a subscription and tests DNS resolution for all records.

.DESCRIPTION
    This script retrieves all private DNS zones in the current Azure subscription,
    gets all DNS records (focusing on A records and CNAMEs), and performs comprehensive 
    DNS resolution testing using Resolve-DnsName. Results are exported to three CSV files:
    one for zone/A record summary, one for detailed resolution results, and one for zone 
    summary statistics showing record counts per zone.

.PARAMETER SubscriptionId
    The Azure subscription ID to query. If not provided, uses the current context.

.PARAMETER ZoneRecordsOutputPath
    Path for the zone and A records CSV file. Defaults to current directory.

.PARAMETER ResolutionOutputPath
    Path for the DNS resolution results CSV file. Defaults to current directory.

.PARAMETER ZoneSummaryOutputPath
    Path for the zone summary statistics CSV file. Defaults to current directory.

.PARAMETER DNSServer
    DNS server to use for resolution testing. If not specified, uses system default.

.EXAMPLE
    .\Get-PrivateDNSZoneResolution_v2.ps1 -ZoneRecordsOutputPath "C:\temp\dns-zones.csv"

.EXAMPLE
    .\Get-PrivateDNSZoneResolution_v2.ps1 -ZoneRecordsOutputPath "C:\temp\dns-zones.csv" -ResolutionOutputPath "C:\temp\dns-resolution.csv"

.EXAMPLE
    .\Get-PrivateDNSZoneResolution_v2.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -DNSServer "168.63.129.16"

.EXAMPLE
    .\Get-PrivateDNSZoneResolution_v2.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ZoneSummaryOutputPath "C:\temp\zone-summary.csv"
#>

# infoblox DNS servers nonprod 10.208.180.39. 
# nonprod  -SubscriptionId 09501f77-01a8-4aed-9b7b-127060676ec4 -DNSServer 10.208.180.39
# .\Get-PrivateDNSZoneResolution_v2.ps1 -SubscriptionId 9458f9de-55ca-4777-ae7d-353b870f5b27 -DNSServer 10.208.180.39

param(
    [string]$SubscriptionId = '9458f9de-55ca-4777-ae7d-353b870f5b27',
    [string]$ZoneRecordsOutputPath = "",
    [string]$ResolutionOutputPath = "",
    [string]$ZoneSummaryOutputPath = "",
    [string]$DNSServer
)

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to test comprehensive DNS resolution
function Test-ComprehensiveDNSResolution {
    param(
        [string]$Hostname,
        [string]$DNSServer = $null
    )
    
    $resolutionResults = @()
    
    try {
        $resolveParams = @{
            Name = $Hostname
            ErrorAction = 'Stop'
        }
        
        if ($DNSServer) {
            $resolveParams.Server = $DNSServer
        }
        
        $result = Resolve-DnsName @resolveParams
        
        if ($result) {
            # Process A records
            $aRecords = $result | Where-Object { $_.Type -eq 'A' }
            foreach ($aRecord in $aRecords) {
                $resolutionResults += [PSCustomObject]@{
                    QueryType = 'A'
                    Success = $true
                    IPAddress = $aRecord.IPAddress
                    CNAME = $null
                    Error = $null
                }
            }
            
            # Process CNAME records
            $cnameRecords = $result | Where-Object { $_.Type -eq 'CNAME' }
            foreach ($cnameRecord in $cnameRecords) {
                $resolutionResults += [PSCustomObject]@{
                    QueryType = 'CNAME'
                    Success = $true
                    IPAddress = $null
                    CNAME = $cnameRecord.NameHost
                    Error = $null
                }
                
                # Try to resolve the CNAME target
                try {
                    $cnameResolveParams = @{
                        Name = $cnameRecord.NameHost
                        Type = 'A'
                        ErrorAction = 'Stop'
                    }
                    
                    if ($DNSServer) {
                        $cnameResolveParams.Server = $DNSServer
                    }
                    
                    $cnameResult = Resolve-DnsName @cnameResolveParams
                    $cnameARecords = $cnameResult | Where-Object { $_.Type -eq 'A' }
                    
                    foreach ($cnameARecord in $cnameARecords) {
                        $resolutionResults += [PSCustomObject]@{
                            QueryType = 'CNAME_RESOLVED'
                            Success = $true
                            IPAddress = $cnameARecord.IPAddress
                            CNAME = $cnameRecord.NameHost
                            Error = $null
                        }
                    }
                }
                catch {
                    $resolutionResults += [PSCustomObject]@{
                        QueryType = 'CNAME_RESOLVED'
                        Success = $false
                        IPAddress = $null
                        CNAME = $cnameRecord.NameHost
                        Error = "Failed to resolve CNAME target: $($_.Exception.Message)"
                    }
                }
            }
            
            # If no A or CNAME records found, check for other types
            if (-not $aRecords -and -not $cnameRecords) {
                $otherRecords = $result | Where-Object { $_.Type -notin @('A', 'CNAME') }
                if ($otherRecords) {
                    $resolutionResults += [PSCustomObject]@{
                        QueryType = 'OTHER'
                        Success = $true
                        IPAddress = ($otherRecords | Select-Object -ExpandProperty IPAddress -ErrorAction SilentlyContinue) -join '; '
                        CNAME = $null
                        Error = "Non-A/CNAME record types found: $($otherRecords.Type -join ', ')"
                    }
                } else {
                    $resolutionResults += [PSCustomObject]@{
                        QueryType = 'NO_RESULT'
                        Success = $false
                        IPAddress = $null
                        CNAME = $null
                        Error = "No usable DNS records found"
                    }
                }
            }
        } else {
            $resolutionResults += [PSCustomObject]@{
                QueryType = 'FAILED'
                Success = $false
                IPAddress = $null
                CNAME = $null
                Error = "No resolution result returned"
            }
        }
    }
    catch {
        $resolutionResults += [PSCustomObject]@{
            QueryType = 'FAILED'
            Success = $false
            IPAddress = $null
            CNAME = $null
            Error = $_.Exception.Message
        }
    }
    
    return $resolutionResults
}

# Main script execution
try {
    Write-ColorOutput "=== Azure Private DNS Zone Resolution Test ===" "Cyan"
    Write-ColorOutput "Starting at: $(Get-Date)" "Gray"
    
    # Check if user is logged into Azure
    $context = Get-AzContext
    if (-not $context) {
        Write-ColorOutput "No Azure context found. Please run Connect-AzAccount first." "Red"
        exit 1
    }
    
    # Set subscription if provided
    if ($SubscriptionId) {
        Write-ColorOutput "Setting subscription context to: $SubscriptionId" "Yellow"
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }
    
    $currentContext = Get-AzContext
    Write-ColorOutput "Using subscription: $($currentContext.Subscription.Name) ($($currentContext.Subscription.Id))" "Green"
    
    # Create output folder based on datetime
    $runDateTime = Get-Date -Format 'yyyyMMdd-HHmmss'
    $outputFolder = ".\reports\$runDateTime"
    
    # Create the folder if it doesn't exist
    if (-not (Test-Path -Path $outputFolder)) {
        Write-ColorOutput "Creating output folder: $outputFolder" "Yellow"
        New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
    } else {
        Write-ColorOutput "Using existing output folder: $outputFolder" "Gray"
    }
    
    # Set default output paths if not provided
    if (-not $ZoneRecordsOutputPath) {
        $ZoneRecordsOutputPath = Join-Path $outputFolder "DNS-Zones-ARecords.csv"
    }
    if (-not $ResolutionOutputPath) {
        $ResolutionOutputPath = Join-Path $outputFolder "DNS-Resolution-Results.csv"
    }
    if (-not $ZoneSummaryOutputPath) {
        $ZoneSummaryOutputPath = Join-Path $outputFolder "DNS-Zone-Summary.csv"
    }
    
    Write-ColorOutput "Zone records will be saved to: $ZoneRecordsOutputPath" "Gray"
    Write-ColorOutput "Resolution results will be saved to: $ResolutionOutputPath" "Gray"
    Write-ColorOutput "Zone summary will be saved to: $ZoneSummaryOutputPath" "Gray"
    
    # Get all private DNS zones
    Write-ColorOutput "`nRetrieving private DNS zones..." "Yellow"
    $privateDnsZones = Get-AzPrivateDnsZone
    
    if (-not $privateDnsZones) {
        Write-ColorOutput "No private DNS zones found in the subscription." "Yellow"
        return
    }
    
    Write-ColorOutput "Found $($privateDnsZones.Count) private DNS zone(s)" "Green"
    
    # Initialize results arrays and deduplication tracking
    $zoneARecords = @()  # For zones and A records
    $resolutionResults = @()  # For detailed resolution results
    $zoneSummary = @()  # For zone summary statistics
    $totalRecords = 0
    
    # Hash tables for deduplication
    $zoneRecordDedup = @{}  # Track unique zone records
    $resolutionDedup = @{}  # Track unique resolution results
    
    # Process each DNS zone
    foreach ($zone in $privateDnsZones) {
        Write-ColorOutput "`nProcessing zone: $($zone.Name)" "Cyan"
                # Initialize counters for this zone
        $zoneRecordCount = 0
        $zoneARecordCount = 0
        $zoneCNAMECount = 0
        $zoneOtherCount = 0
                try {
            # Get all record sets for the zone
            $recordSets = Get-AzPrivateDnsRecordSet -ZoneName $zone.Name -ResourceGroupName $zone.ResourceGroupName
            
            Write-ColorOutput "  Found $($recordSets.Count) record set(s) in zone $($zone.Name)" "Gray"
            
            foreach ($recordSet in $recordSets) {
                # Skip SOA and NS records at zone apex
                if ($recordSet.RecordType -in @('SOA', 'NS') -and $recordSet.Name -eq '@') {
                    continue
                }
                
                # Process A and CNAME records primarily
                switch ($recordSet.RecordType) {
                    'A' {
                        foreach ($record in $recordSet.Records) {
                            $hostname = if ($recordSet.Name -eq '@') { $zone.Name } else { "$($recordSet.Name).$($zone.Name)" }
                            
                            Write-ColorOutput "    Processing A record: $hostname -> $($record.Ipv4Address)" "Gray"
                            
                            $totalRecords++
                            $zoneRecordCount++
                            $zoneARecordCount++
                            
                            # Create unique key for zone record deduplication
                            $zoneRecordKey = "$($zone.Name)|$($recordSet.Name)|$($recordSet.RecordType)|$hostname|$($record.Ipv4Address)"
                            
                            # Add to zone A records summary (only if not duplicate)
                            if (-not $zoneRecordDedup.ContainsKey($zoneRecordKey)) {
                                $zoneRecordDedup[$zoneRecordKey] = $true
                                $zoneARecords += [PSCustomObject]@{
                                    ZoneName = $zone.Name
                                    ResourceGroup = $zone.ResourceGroupName
                                    RecordName = $recordSet.Name
                                    RecordType = $recordSet.RecordType
                                    Hostname = $hostname
                                    ConfiguredIP = $record.Ipv4Address
                                    TTL = $recordSet.Ttl
                                    TestTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                                }
                            }
                            
                            # Perform comprehensive DNS resolution
                            $resolutionData = Test-ComprehensiveDNSResolution -Hostname $hostname -DNSServer $DNSServer
                            
                            # Add each resolution result (only if not duplicate)
                            foreach ($resolution in $resolutionData) {
                                $resolutionKey = "$hostname|$($resolution.QueryType)|$($resolution.IPAddress)|$($resolution.CNAME)|$($resolution.Success)"
                                
                                if (-not $resolutionDedup.ContainsKey($resolutionKey)) {
                                    $resolutionDedup[$resolutionKey] = $true
                                    $resolutionResults += [PSCustomObject]@{
                                        ZoneName = $zone.Name
                                        ResourceGroup = $zone.ResourceGroupName
                                        RecordName = $recordSet.Name
                                        RecordType = $recordSet.RecordType
                                        Hostname = $hostname
                                        ConfiguredIP = $record.Ipv4Address
                                        QueryType = $resolution.QueryType
                                        ResolvedIP = $resolution.IPAddress
                                        CNAME = $resolution.CNAME
                                        ResolutionSuccess = $resolution.Success
                                        Error = $resolution.Error
                                        DNSServer = if ($DNSServer) { $DNSServer } else { "System Default" }
                                        TestTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                                    }
                                } else {
                                    Write-ColorOutput "      Skipping duplicate resolution result for: $hostname ($($resolution.QueryType))" "DarkGray"
                                }
                            }
                        }
                    }
                    'CNAME' {
                        foreach ($record in $recordSet.Records) {
                            $hostname = if ($recordSet.Name -eq '@') { $zone.Name } else { "$($recordSet.Name).$($zone.Name)" }
                            
                            Write-ColorOutput "    Processing CNAME record: $hostname -> $($record.Cname)" "Gray"
                            
                            $totalRecords++
                            $zoneRecordCount++
                            $zoneCNAMECount++
                            
                            # Create unique key for zone record deduplication
                            $zoneRecordKey = "$($zone.Name)|$($recordSet.Name)|$($recordSet.RecordType)|$hostname|$($record.Cname)"
                            
                            # Add to zone records summary (CNAMEs are important for resolution) - only if not duplicate
                            if (-not $zoneRecordDedup.ContainsKey($zoneRecordKey)) {
                                $zoneRecordDedup[$zoneRecordKey] = $true
                                $zoneARecords += [PSCustomObject]@{
                                    ZoneName = $zone.Name
                                    ResourceGroup = $zone.ResourceGroupName
                                    RecordName = $recordSet.Name
                                    RecordType = $recordSet.RecordType
                                    Hostname = $hostname
                                    ConfiguredIP = $record.Cname
                                    TTL = $recordSet.Ttl
                                    TestTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                                }
                            }
                            
                            # Perform comprehensive DNS resolution
                            $resolutionData = Test-ComprehensiveDNSResolution -Hostname $hostname -DNSServer $DNSServer
                            
                            # Add each resolution result (only if not duplicate)
                            foreach ($resolution in $resolutionData) {
                                $resolutionKey = "$hostname|$($resolution.QueryType)|$($resolution.IPAddress)|$($resolution.CNAME)|$($resolution.Success)"
                                
                                if (-not $resolutionDedup.ContainsKey($resolutionKey)) {
                                    $resolutionDedup[$resolutionKey] = $true
                                    $resolutionResults += [PSCustomObject]@{
                                        ZoneName = $zone.Name
                                        ResourceGroup = $zone.ResourceGroupName
                                        RecordName = $recordSet.Name
                                        RecordType = $recordSet.RecordType
                                        Hostname = $hostname
                                        ConfiguredIP = $record.Cname
                                        QueryType = $resolution.QueryType
                                        ResolvedIP = $resolution.IPAddress
                                        CNAME = $resolution.CNAME
                                        ResolutionSuccess = $resolution.Success
                                        Error = $resolution.Error
                                        DNSServer = if ($DNSServer) { $DNSServer } else { "System Default" }
                                        TestTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                                    }
                                } else {
                                    Write-ColorOutput "      Skipping duplicate resolution result for: $hostname ($($resolution.QueryType))" "DarkGray"
                                }
                            }
                        }
                    }
                    default {
                        # Document other record types but don't process them for resolution
                        $hostname = if ($recordSet.Name -eq '@') { $zone.Name } else { "$($recordSet.Name).$($zone.Name)" }
                        
                        Write-ColorOutput "    Documenting $($recordSet.RecordType) record: $hostname" "DarkGray"
                        $totalRecords++
                        $zoneRecordCount++
                        $zoneOtherCount++
                        
                        # Create unique key for zone record deduplication
                        $zoneRecordKey = "$($zone.Name)|$($recordSet.Name)|$($recordSet.RecordType)|$hostname|N/A - $($recordSet.RecordType) Record"
                        
                        # Add only if not duplicate
                        if (-not $zoneRecordDedup.ContainsKey($zoneRecordKey)) {
                            $zoneRecordDedup[$zoneRecordKey] = $true
                            $zoneARecords += [PSCustomObject]@{
                                ZoneName = $zone.Name
                                ResourceGroup = $zone.ResourceGroupName
                                RecordName = $recordSet.Name
                                RecordType = $recordSet.RecordType
                                Hostname = $hostname
                                ConfiguredIP = "N/A - $($recordSet.RecordType) Record"
                                TTL = $recordSet.Ttl
                                TestTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                            }
                        }
                    }
                }
            }
            # Add zone summary statistics
            $zoneSummary += [PSCustomObject]@{
                ZoneName = $zone.Name
                ResourceGroup = $zone.ResourceGroupName
                TotalRecords = $zoneRecordCount
                ARecords = $zoneARecordCount
                CNAMERecords = $zoneCNAMECount
                OtherRecords = $zoneOtherCount
                TestTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
        catch {
            Write-ColorOutput "  Error processing zone $($zone.Name): $($_.Exception.Message)" "Red"
            
            $zoneARecords += [PSCustomObject]@{
                ZoneName = $zone.Name
                ResourceGroup = $zone.ResourceGroupName
                RecordName = "ERROR"
                RecordType = "ERROR"
                Hostname = "ERROR"
                ConfiguredIP = "ERROR"
                TTL = "ERROR"
                TestTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            
            $resolutionResults += [PSCustomObject]@{
                ZoneName = $zone.Name
                ResourceGroup = $zone.ResourceGroupName
                RecordName = "ERROR"
                RecordType = "ERROR"
                Hostname = "ERROR"
                ConfiguredIP = "ERROR"
                QueryType = "ERROR"
                ResolvedIP = "ERROR"
                CNAME = "ERROR"
                ResolutionSuccess = $false
                Error = "Failed to retrieve records: $($_.Exception.Message)"
                DNSServer = if ($DNSServer) { $DNSServer } else { "System Default" }
                TestTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            
            # Add error entry to zone summary
            $zoneSummary += [PSCustomObject]@{
                ZoneName = $zone.Name
                ResourceGroup = $zone.ResourceGroupName
                TotalRecords = 0
                ARecords = 0
                CNAMERecords = 0
                OtherRecords = 0
                TestTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    }
    
    # Export results to CSV files
    Write-ColorOutput "`nExporting results to CSV files..." "Yellow"
    
    # Remove duplicates one final time before export (extra safety)
    $uniqueZoneRecords = $zoneARecords | Sort-Object ZoneName, RecordName, RecordType, Hostname, ConfiguredIP -Unique
    $uniqueResolutionResults = $resolutionResults | Sort-Object Hostname, QueryType, ResolvedIP, CNAME, ResolutionSuccess -Unique
    
    # Calculate duplicate counts
    $zoneRecordDuplicates = $zoneARecords.Count - $uniqueZoneRecords.Count
    $resolutionDuplicates = $resolutionResults.Count - $uniqueResolutionResults.Count
    
    # Export zone and A records summary
    $uniqueZoneRecords | Export-Csv -Path $ZoneRecordsOutputPath -NoTypeInformation -Encoding UTF8
    Write-ColorOutput "Zone and A records exported to: $ZoneRecordsOutputPath" "Green"
    
    # Export DNS resolution results
    $uniqueResolutionResults | Export-Csv -Path $ResolutionOutputPath -NoTypeInformation -Encoding UTF8
    Write-ColorOutput "DNS resolution results exported to: $ResolutionOutputPath" "Green"
    
    # Export zone summary statistics
    $zoneSummary | Export-Csv -Path $ZoneSummaryOutputPath -NoTypeInformation -Encoding UTF8
    Write-ColorOutput "Zone summary statistics exported to: $ZoneSummaryOutputPath" "Green"
    
    # Summary statistics
    $successfulResolutions = ($uniqueResolutionResults | Where-Object { $_.ResolutionSuccess -eq $true }).Count
    $failedResolutions = ($uniqueResolutionResults | Where-Object { $_.ResolutionSuccess -eq $false }).Count
    $cnameResolutions = ($uniqueResolutionResults | Where-Object { $_.QueryType -eq 'CNAME' }).Count
    $cnameResolvedCount = ($uniqueResolutionResults | Where-Object { $_.QueryType -eq 'CNAME_RESOLVED' }).Count
    
    Write-ColorOutput "`n=== SUMMARY ===" "Cyan"
    Write-ColorOutput "Total zones processed: $($privateDnsZones.Count)" "Green"
    Write-ColorOutput "Total records processed: $totalRecords" "Green"
    Write-ColorOutput "Successful resolutions: $successfulResolutions" "Green"
    Write-ColorOutput "Failed resolutions: $failedResolutions" "Red"
    Write-ColorOutput "CNAME records found: $cnameResolutions" "Yellow"
    Write-ColorOutput "CNAME targets resolved: $cnameResolvedCount" "Yellow"
    Write-ColorOutput "Zone record duplicates removed: $zoneRecordDuplicates" "Magenta"
    Write-ColorOutput "Resolution duplicates removed: $resolutionDuplicates" "Magenta"
    Write-ColorOutput "Unique zone records exported: $($uniqueZoneRecords.Count)" "Green"
    Write-ColorOutput "Unique resolution results exported: $($uniqueResolutionResults.Count)" "Green"
    Write-ColorOutput "`n=== OUTPUT FILES ===" "Cyan"
    Write-ColorOutput "Zone and A records exported to: $ZoneRecordsOutputPath" "Green"
    Write-ColorOutput "DNS resolution results exported to: $ResolutionOutputPath" "Green"
    Write-ColorOutput "Zone summary statistics exported to: $ZoneSummaryOutputPath" "Green"
    Write-ColorOutput "Completed at: $(Get-Date)" "Gray"
    
    # Display file locations
    $fullZonePath = Resolve-Path $ZoneRecordsOutputPath
    $fullResolutionPath = Resolve-Path $ResolutionOutputPath
    $fullSummaryPath = Resolve-Path $ZoneSummaryOutputPath
    Write-ColorOutput "`nFull path to zone/A records: $fullZonePath" "Cyan"
    Write-ColorOutput "Full path to resolution results: $fullResolutionPath" "Cyan"
    Write-ColorOutput "Full path to zone summary: $fullSummaryPath" "Cyan"
    
}
catch {
    Write-ColorOutput "Script execution failed: $($_.Exception.Message)" "Red"
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Red"
    exit 1
}
