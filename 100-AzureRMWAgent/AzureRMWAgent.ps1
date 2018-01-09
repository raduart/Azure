<#
    .SCRIPT SYNOPSIS 
        ARM environment 
        List or install/reinstall latest Windows Azure Guest Agent
	  
	.Description
        ARM environment 
        List or install/reinstall latest Windows Azure Guest Agent

	.Parameter SubID
		Mandatory: This item is the Subscription ID that will be used
		Alias: S

	.Parameter rgName
		Optional: This item is the Resource Group Name that will be used
		Alias: RG

	.Parameter vmName
		Optional: This item is the Virtual Machine Name that will be used
		Alias: VM

	.Parameter InstallWAgent
		Optional: This switch is to install\reinstall Windows Azure Guest Agent

	.Parameter logPath
		Optional: This item is the path to export logs and Json file. Will be created if doesn't exists.

	.Example
		.\AzureRMWAgent.ps1 -SubID "aaaaaaaa-0000-1111-3333-bbbbbbbbbbbb" `
                            [-RG "<ResourceGroup" `]
                            [-VM "<VMName>" `]
                            [-InstallWAgent `]
                            [-logPath "C:\Temp2" `]
                            
    .Author  
        Rafael Duarte
		Created By Rafael Duarte
		Email raduart@microsoft.com		

    .Credits

    .Notes / Versions / Output
    	* Version: 1.0
		  Date: January 8th 2018
		  Purpose/Change:	Initial function development
          # Constrains / Pre-requisites:
            > none
          # Output
            > Creates a Transcript File
#>

Param(
    [Parameter(Mandatory=$true, HelpMessage="Enter the name of the Azure Subscription you want to use and Press <Enter> e.g. aaaaaaaa-0000-1111-3333-bbbbbbbbbbbb")]
    [Alias('S')]
    [String]$subID,

    [Parameter(Mandatory=$false, HelpMessage="Enter the name of the Azure Resource Group where is the VM and Press <Enter>")]
    [Alias('RG')]
    [String]$rgName,

    [Parameter(Mandatory=$false, HelpMessage="Enter the name of the Azure Virtual Machine and Press <Enter>")]
    [Alias('VM')]
    [String]$vmName,

    [Parameter(Mandatory=$false, HelpMessage="Enter the Path where to export Logs\JSON File and Press <Enter>")]
    [Alias('P')]
    [String]$logPath = "C:\Temp",

    [Parameter(Mandatory=$false, HelpMessage="This switch is to install\reinstall Windows Azure Guest Agent.")]
    [Switch]$InstallWAgent = $false
)

# Set the variables: 
if (!(Test-Path -path $logPath)) {New-Item -Path $logPath -ItemType "directory"}
$rnd = Get-Date -Format "yyyyMMddHHmmss"
$transcriptFile = "$($logPath)\AzureRMWAgent_$($rnd).transcript"
$CSVFile = "$($logPath)\AzureRMWAgent_$($rnd).csv"

$PoSHFilePath = "https://raw.githubusercontent.com/KemTech/Azure/master/100-AzureRMWAgent/AzureRMWAgent_InstallWaga.ps1"
$PoSHFileName = "AzureRMWAgent_InstallWaga.ps1"

# Start Transcript
Start-Transcript -LiteralPath $transcriptFile

# List Input Data
Write-Host "`nStarting PoSH Script ....." 

Write-Host "`n======== Input Data ========" 
Write-Host   "Subscription ID: <$subID>" -ForegroundColor Green
Write-Host   " Resource Group: <$rgName>" -ForegroundColor Green
Write-Host   "             VM: <$vmName>" -ForegroundColor Green
Write-Host   "  Install WALA?: <$InstallWAgent>" -ForegroundColor Yellow
Write-Host   "       Log Path: <$logPath>" -ForegroundColor Yellow

# Login to Azure
Write-Host "`n======== Azure Environment ========" 
Write-Host   "Add Azure Account ..." -ForegroundColor Yellow
Login-AzureRmAccount

Write-Host   "Select Subscription ..." -ForegroundColor Yellow
Select-AzureRmSubscription -SubscriptionID $subID

Write-Host   "Set Azure Context ..." -ForegroundColor Yellow
Set-AzureRmContext -SubscriptionID $subID 

if ($rgName -eq "" -or $rgName -eq $null)
# full subscription
{
    $vmList = Get-AzureRmVM
} 
elseif ($vmName -eq "" -or $vmName -eq $null)
    # full resource Group
    {
        $vmList = Get-AzureRmVM -ResourceGroupName $rgName 
    }
    else
    # VM Only
    {
        $vmList = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName
    }

$vmListStatus = @()
# For Running VM's get's VM status and Agent version and status
foreach ($vm in $vmList) {
    $vmListStatus += (Get-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status | 
        select @{Name="VMRG";Expression={$vm.ResourceGroupName}}, @{Name="VMName";Expression={$vm.Name}}, `
               @{Name="VMOsType";Expression={$vm.StorageProfile.OsDisk.OsType}}, @{Name="VMLocation";Expression={$vm.Location}}, `
               VMAgent -ExpandProperty Statuses | 
            where code -like "PowerState*" | 
                where code -like "*running*" | 
                    select VMRG, VMName, VMOsType, VMLocation, @{Name="VMDisplayStatus";Expression={$_.DisplayStatus}} -ExpandProperty VMAgent | 
                        select VMRG, VMName, VMOsType, VMLocation, VMDisplayStatus, VMAgentVersion -ExpandProperty Statuses |
                            select VMRG, VMName, VMOsType, VMLocation, VMDisplayStatus, VMAgentVersion, @{Name="VMAgentDisplayStatus";Expression={$_.DisplayStatus}}, @{Name="VMAgentMessage";Expression={$_.Message}}, @{Name="VMAgentTime";Expression={$_.Time}} )
}


# For NOT Running VM's get's only VM status
foreach ($vm in $vmList) {
    $vmListStatus += (Get-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status | 
        select @{Name="VMRG";Expression={$vm.ResourceGroupName}}, @{Name="VMName";Expression={$vm.Name}}, @{Name="VMOsType";Expression={$vm.StorageProfile.OsDisk.OsType}}, @{Name="VMLocation";Expression={$vm.Location}}, VMAgent -ExpandProperty Statuses | 
            where code -like "PowerState*" | 
                where code -NotLike "*running*" | 
                    select VMRG, VMName, VMOsType, VMLocation, @{Name="VMDisplayStatus";Expression={$_.DisplayStatus}}, @{Name="VMAgentVersion";Expression={"N/A"}}, @{Name="VMAgentDisplayStatus";Expression={"N/A"}}, @{Name="VMAgentMessage";Expression={"N/A"}}, @{Name="VMAgentTime";Expression={"N/A"}} )
}

# Export VM List to CSV File
$vmListStatus | Export-Csv -Path $CSVFile -NoTypeInformation -Delimiter ";" 

# If Switch InstallWAgent selected will push custom script to install Azure Client
if ($InstallWAgent)
{
    # selecting only runnig Windows VM and with Agent ok
    $vmListWindows = ($vmListStatus | where VMOsType -EQ "Windows" | where VMDisplayStatus -like "*running*" | where VMAgentDisplayStatus -like "Ready") 
    foreach ($vmWin in $vmListWindows) {
        Write-Host "`n Adding CustomScript extension to $($vmWin.VMRG) - $($vmWin.VMName)......" -ForegroundColor Yellow
        Set-AzureRmVMCustomScriptExtension `
            -ResourceGroupName $vmWin.VMRG `
            -VMName $vmWin.VMName `
            -Location $vmWin.VMLocation `
            -FileUri $PoSHFilePath `
            -Run $PoSHFileName `
            -Name WagaCustomInstall
    }
}

Stop-Transcript
