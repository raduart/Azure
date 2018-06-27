##### Begin - Change variables accordantly to your data ###########
$RGName = "rd2373"
$VMName = "rd2373os2016"
$LocationName = "West Europe"
$SuffixDiskName = "-ImgDisk"
$VMImageName = $VMName + "-ImgDisk"
##### End - Change variables accordantly to your data ###########

#$AzureContext = "ourcontext"
#Add-AzureRMLogin
#Set-AzureRmContext $AzureContext # Presumes a saved context for the proper account & subscription

#Import-Module AzureRm.NetCore -MinimumVersion 0.10.0
#Import-Module AzureRM -MinimumVersion 5.5.0

#######
# IMPORTANT: SYSPREP VM and Shutdown\Deallocate before proceed
#######

$VmStatus = Get-AzureRmVM -Status -Name $VMName -ResourceGroupName $RGName
foreach ($Status in $VmStatus.Statuses)
{
    if (($Status.Code).Contains("PowerState") -and !(($Status.Code).Contains("deallocated")))
    {
        Write-Host "$VMName status $($Status.Code)" -ForegroundColor Yellow
        $Continue = Read-Host "Need to stop/deallocate $VMName; Are you sure? Enter y to continue"
        if ($Continue.ToLower() -ne 'y')
        {
            Write-Host "`n######### ERROR - PROCESS CANCELED !!! #########" -ForegroundColor Red
            Write-Host "$VMNAme cannot be Copied if not deallocated" -ForegroundColor Yellow
            Write-Host "Exiting"
            Throw
        }
        Write-Host "Stopping $VMName"
        Stop-AzureRmVM -Name $VMName -ResourceGroupName $RGName -Force
    }
}

$DisksList  = @()

#OS Disk
$OSDisk = (Get-AzureRmVM -Name $VMName -ResourceGroupName $RGName).StorageProfile.OSDisk # There is always just one OsDisk
$DisksList += $OSDisk.Name

#Data Disks
$DataDisks = (Get-AzureRmVM -Name $VMName -ResourceGroupName $RGName).StorageProfile.DataDisks # There might be a collection of data disks
foreach ($DataDisk in $DataDisks)
{
    $DisksList += $DataDisk.Name # Disk Name
}

# Make Copy of disks
$ImgDiskList  = @()
foreach ($Disk in $DisksList)
{
    $DiskID = (Get-AzureRmDisk -ResourceGroupName $RGName -DiskName $Disk).Id
    $DiskConfig = New-AzureRmDiskConfig -SourceUri $DiskID -Location $LocationName -CreateOption Copy
    $DiskName = ($Disk + $SuffixDiskName )
    Write-Host "`n    Disk Name: <$Disk>"
    Write-Host   "      Disk ID: <$DiskID>"
    Write-Host   "New Disk Name: <$DiskName>"
    New-AzureRmDisk -Disk $DiskConfig -DiskName $DiskName -ResourceGroupName $RGName
    $ImgDiskList += $DiskName
}

#Make VM Image
$VMImageConfig = New-AzureRmImageConfig -Location $LocationName

foreach ($Disk in $ImgDiskList)
{
    #OS Disk
    if ($ImgDiskList.IndexOf($Disk) -eq 0) {
        Set-AzureRmImageOsDisk -Image $VMImageConfig -OsState Generalized -OsType Windows -ManagedDiskId (Get-AzureRmDisk -ResourceGroupName $RGName -DiskName $Disk).Id -Caching ReadWrite
    } else {
        Add-AzureRmImageDataDisk -Image $VMImageConfig -ManagedDiskId (Get-AzureRmDisk -ResourceGroupName $RGName -DiskName $Disk).Id -Caching ReadWrite -Lun ($ImgDiskList.IndexOf($Disk)-1)
    }
}

New-AzureRmImage -ImageName $VMImageName -ResourceGroupName $RGName -Image $VMImageConfig
