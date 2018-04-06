<#
    .SCRIPT SYNOPSIS 
        ARM environment 
        Copy a Managed Disk to a vhd blob on a specified storage account \ container
        Supports different AD tenant or location on target subscription
        For a new location\Region create target Storage Account on that new region
	  
	.Description
        Copy a Managed Disk to a vhd blob on a specified storage account \ container
        Supports different AD tenant or location on target subscription
        For a new location\Region create target Storage Account on that new region

	.Parameter Help
		Optional: This item will display syntax help
		Alias: H

	.Parameter SubId
		Mandatory: This item is the Subscription ID that will be used
		Alias: S

	.Parameter RGName
		Mandatory: This item is the Resource Group Name that will be used
		Alias: RG

	.Parameter DiskName
		Mandatory: This item is the Disk\Snapshot Name that will be used
		Alias: Name

	.Parameter Snapshot
		Mandatory: This switch will managed this disk as a source snapshot
		Alias: Snapshot

	.Parameter ToURI
		Mandatory: This item is the Destination URI to container where blob will be copied

	.Parameter ToSaS
		Mandatory: This item is the Destination SAS to target container with write permissions

	.Parameter Snapshot
		Optional: This item indicates that the Disk Name it will be used as a Snapshot Managed Disk Name

	.Parameter AZCopyPath
		Optional: Path where AZCopy is installed. Default path "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy"

	.Parameter OutputPath
		Optional: Output files will be creates on this path. Default path "$env:USERPROFILE\Documents\PoSH_Logs\"

	.Example
		.\AzureRMCopyManagedDisks_Different_Tenant_Location.ps1 `
                -SubId "aaaaaaaa-0000-1111-3333-bbbbbbbbbbbb" `
                -RGName "<ResourceGroup" `                -DiskName "<ManageDisk/Snapshot/Name>" `                -ToURI "<TargetURI>" `                -ToSAS "<TargetSASContainer>" 
                [-Snapshot]
                [-AZCopyPath "<Full AZCopy Path>"]
                [-OutputPath "<Full Logs Path>"]
                [-Help]

    .Author  
        Rafael Duarte
		Created By Rafael Duarte
		Email raduart@microsoft.com		

    .Credits

    .Notes / Versions / Output
    	* Version: 1.0
		  Date: April 06th 2018
		  Purpose/Change:	Initial function development
          # Constrains / Pre-requisites:
            > Target Storage Account has to be created.
			> Create a SAS (Shared Access Signature) with write permissions on target Container
          # Output
            > Creates a Transcript File (<ScriptName>_<TrackTimeStamp>.txt)
            > Creates a vhd blob on destination Storage Account \ container
#>
	Param(
	[Parameter(Mandatory=$false)][Alias('H')][Switch]$Help,
	[Parameter(Mandatory=$false)][Switch]$Snapshot,
	[Parameter(Mandatory=$false)][String]$OutputPath = "",
	[Parameter(Mandatory=$false)][String]$AZCopyPath = "",
	[Parameter(Mandatory=$false)][Alias('S')][String]$SubId = "",
	[Parameter(Mandatory=$false)][Alias('RG')][String]$RGName = "",
	[Parameter(Mandatory=$false)][Alias('Name')][String]$DiskName = "",
	[Parameter(Mandatory=$false)][String]$ToURI = "",
	[Parameter(Mandatory=$false)][String]$ToSAS = "")
<#
    .Function SYNOPSIS - ErrorMsgCentral
      Displays a custom message to console output depending on MsgID
	  
	.Description
	  	This function helps to centralize all custom messages to console output
	  	depending on MsgID selected.

	.Parameter MsgID
		Mandatory: This item idenfify message to be displayed on console output
		Alias: ID

	.Parameter MsgData
		Optional: Additional data that can be used when displaying message to console output
		Alias: Data

	.Example
		ErrorMsgCentral -ID 10 -Data "Demo"
		
		This example will output error message assign to ID 10 and may use "Demo" string
        to be added on Message ID selected.

	.Notes
		Created By Rafael Duarte
		Email raduart@microsoft.com		

		Version: 1.0
		Date: April 06th 2018
		Purpose/Change:	Initial function development

    .Link

#>
function ErrorMsgCentral{
	Param(
	[Parameter(Mandatory=$True)][Alias('ID')][Int32]$MsgID,
	[Parameter(Mandatory=$False)][Alias('Data')][String]$MsgData)

    switch ($MsgID) 
    { 
        0   {$MsgTxt = ""}
        5   {$MsgTxt = "Syntax: $MsgData" + `
		     "`n`n .\$($ScriptName).ps1 ``" + `             "`n      -SubID `"<SubscriptionID>`" ``" + `
             "`n      -RGName `"<ResourceGroup>`" ``" + `
             "`n      -DiskName `"<ManageDisk/Snapshot/Name>`" ``" + `             "`n      -ToURI `"<TargetURI>`" ``" + `             "`n      -ToSAS `"<TargetSASContainer>`" ``" + `
             "`n      [-OutputPath `"<Full Logs Path>`"] ``" + `
             "`n      [-AZCopyPath `"<Full AZCopy Path>`"] ``" + `
             "`n      [-Snapshot] ``" + `
             "`n      [-Help]"
            }
        6  {$MsgTxt = "Error: Missing AZCopy ! $MsgData`n"}
        10  {$MsgTxt = "Error: Invalid Authentication ! $MsgData`n"}
        30  {$MsgTxt = "Error: Invalid Resource Name <$($MsgData)>!"}
        31  {$MsgTxt = "Error: Error creating Storage Account <$($MsgData)>!"}
        32  {$MsgTxt = "Error: Error creating Container! $($MsgData)>!"}
        33  {$MsgTxt = "Error: Error creating SAS! $($MsgData)>!"}
        default {$MsgTxt = "Error unknown !!!"}

    }
    If ($MsgID -gt 0)
    {
        Write-Host "`n<$MsgID>" -ForegroundColor Yellow 
        Write-Host $MsgTxt -ForegroundColor Red 
    }
    Write-Host "`n####### End - PoSH script $ScriptName.ps1 #######" -ForegroundColor Green
    Stop-Transcript
}

### Parameters / Constants ###
## Get Script Name
    # invocation from POSH Command Line
    $ScriptName = $MyInvocation.MyCommand.Name
    if (($ScriptName -eq $null) -or ($ScriptName -eq ""))
    {
        # invocation from POSH ISE Environment
        $ScriptName = ($psISE.CurrentFile.DisplayName).Replace("*","")
    }
    $ScriptName = $ScriptName.Replace(".ps1","")

## Files / logs / Paths
    $TrackTimeStamp = "$('{0:yyyyMMddHHmmss}_{1,-1}' -f $(Date), $(Get-Random))" 
    if ($OutputPath -eq "")
    {
        $OutputPath = "$env:USERPROFILE\Documents\PoSH_Logs"
    }

    $TranscriptPath = "$OutputPath\Transcripts\"
    if (!(Test-Path -LiteralPath $TranscriptPath -PathType Container)) 
        {Invoke-Command -ScriptBlock {md $TranscriptPath}}
    $LogPath        = "$OutputPath\Logs\"
    if (!(Test-Path -LiteralPath $LogPath -PathType Container)) 
        {Invoke-Command -ScriptBlock {md $LogPath}}
    $TranscriptFile = $TranscriptPath + $ScriptName + "_" + $TrackTimeStamp + ".txt"

## Setting PoSH Execution Policy to Lowest
    #Set-ExecutionPolicy -ExecutionPolicy Bypass -Force

### Main Script ###
    Clear

## Track Log
    Start-Transcript $TranscriptFile

## Begin Script
    Write-Host "`n####### Begin - PoSH script $ScriptName.ps1 #######`n" -ForegroundColor Green
    Write-Host " Start Timestamp: $('{0:yyyy-MM-dd HH:mm:ss}' -f $(Date))" 

## Parameters Validation
### Help Switch for syntax
    If ($Help)
    {
        ErrorMsgCentral -ID 5
        Throw
    }

### Required parameters
    If (($SubId -eq "") -or `
        ($RGName -eq "") -or `
        ($DiskName -eq "") -or `
        ($ToURI -eq "") -or `
        ($ToSAS -eq ""))
    {
        ErrorMsgCentral -ID 5 -MsgData "Missing Parameters !"
        Throw
    }
### Check if AZCopy path exists
    if ($AZCopyPath -eq "")
    {
        $AZCopyPath = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy"
    }
    if (!(Test-Path -LiteralPath $AZCopyPath -PathType Container)) 
    {
        ErrorMsgCentral -ID 6 -MsgData "AZCopy Path doesn't exists !"
        Throw
    }
## Set Full path destination URI
$ToFullURI = "$ToURI/$DiskName.vhd"

## Authenticate Azure ARM
    Write-Host "`n Authenticating Azure ARM ....." -ForegroundColor Yellow
    Add-AzureRMAccount -ErrorAction SilentlyContinue -ErrorVariable RC_Err > $null
    if ($RC_Err.Count -gt 0)
    {
        ErrorMsgCentral -ID 10 -Data "Login to Azure ARM"
        Throw
    }

# Select Subscription
    Select-AzureRmSubscription -SubscriptionID $subID -ErrorAction SilentlyContinue -ErrorVariable ErrSub
    if ($ErrSub.Count -gt 0)
    {
        ErrorMsgCentral -ID 10 -Data "Selecting Subscription ID: $($subID)."
        Throw
    }
    Set-AzureRmContext -SubscriptionID $subID -ErrorAction SilentlyContinue -ErrorVariable ErrSub
    if ($ErrSub.Count -gt 0)
    {
        ErrorMsgCentral -ID 10 -Data "Setting Azure ARM Context with Subscription ID: $($subID)."
        Throw
    }

## Resource Group
    Write-Host "`n ==== Input parameters ====" -ForegroundColor Yellow
    Write-Host   "   Subscription ID: <$SubId>" -ForegroundColor Green
    Write-Host   "    Resource Group: <$RGName>" -ForegroundColor Green
    if ($Snapshot)
    {
        Write-Host   "     Snapshot Name: <$DiskName>" -ForegroundColor Green
    } else
        {
            Write-Host   " Managed Disk Name: <$DiskName>" -ForegroundColor Green
        }

## Parameters Validation
## Resource Group
    $rg = Get-AzureRmResourceGroup -Name $RGName -ErrorAction SilentlyContinue -ErrorVariable ErrRes
    if ($ErrRes.Count -gt 0)
    {
        ErrorMsgCentral -ID 30 -Data "Resource Group $($RGName)"
        Throw
    }

## Assuming Parameters
    Write-Host "`n Creating SAS Token to Managed Disk\Snapshot ...." -ForegroundColor Yellow
    if ($Snapshot)
    {
    ## Snapshot Managed Disk Name
        $SASToken = Grant-AzureRmSnapshotAccess -ResourceGroupName $RGName -SnapshotName $DiskName -Access Read -DurationInSecond 3660 -ErrorAction SilentlyContinue -ErrorVariable ErrRes
        if ($ErrRes.Count -gt 0 -or $DiskName -eq $null)
        {
            ErrorMsgCentral -ID 30 -Data "Snapshot Managed Disk Name $($DiskName)"
            Throw
        }
    } else
        {
        ## Managed Disk Name
            $SASToken = Grant-AzureRmDiskAccess -ResourceGroupName $RGName -DiskName $DiskName -Access Read -DurationInSecond 3660 -ErrorAction SilentlyContinue -ErrorVariable ErrRes
            if ($ErrRes.Count -gt 0 -or $DiskName -eq $null)
            {
                ErrorMsgCentral -ID 30 -Data "Managed Disk Name $($DiskName)"
                Throw
            }
        }

## Source SAS Token Split
    $FromURI = ($SASToken.AccessSAS).split("?")[0]
    $FromSAS = "?" + ($SASToken.AccessSAS).split("?")[-1]
    Write-Host "`n         From URI : <$FromURI>" -ForegroundColor Green
    Write-Host   "         From SAS : <$FromSAS>" -ForegroundColor Green
    Write-Host   " ......>>>" -ForegroundColor Green
    Write-Host   "         Dest.URI : <$ToFullURI>" -ForegroundColor Green
    Write-Host   "         Dest.SAS : <$ToSAS>" -ForegroundColor Green

## AZCopy Process
    $AzCopyJournal = "$($OutputPath)\Journal\$DiskName" 
    Write-Host "`n ==== Starting AZCopy ====" -ForegroundColor Yellow
    Write-Host   "     Journal path : <$AzCopyJournal>`n" -ForegroundColor Green
    Write-Host   "       Copy Start : $('{0:yyyy-MM-dd HH:mm:ss}' -f $(Date))" 

    $command = "`"$AZCopyPath\AzCopy.exe`" /Source:`"$FromURI`" /SourceSAS:`"$FromSAS`" /Dest:`"$ToFullURI`" /DestSAS:`"$ToSAS`" /Z:`"$AzCopyJournal`""

    Invoke-Expression "& $command" `
                   -ErrorAction SilentlyContinue `
                   -ErrorVariable ErrAZCopy 

# End Script
    ErrorMsgCentral -ID 0
    
    Write-Host " End Timestamp: $('{0:yyyy-MM-dd HH:mm:ss}' -f $(Date))" 
 
