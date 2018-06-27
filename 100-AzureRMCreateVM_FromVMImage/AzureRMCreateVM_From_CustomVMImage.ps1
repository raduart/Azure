# Creating a VM from custom image "DefaultParameterSet"

##### Begin - Change variables accordantly to your data ###########

$LocationName = "West Europe"

### Data for Source Image
$RGNameImg = "rd2373"
$VMImageName = "rd2373os2016-ImgDisk"

### Data for New VM
## Platform Data
$RGName = "rd2373"
$VMName = "rd2373Posh02"
$VMSize = "Standard_DS2_v2"
$VMOSDiskName = $VMName + "_OSDisk"
$VMOSDiskCaching = "ReadWrite"
$VMDataDiskNamePrefix = $VMName + "_DataDisk_"
$VMDataDiskCaching = "ReadWrite"
$VMSADiagnosticsUri = "https://......."

## Networking
$VMVNetName = "rd2373-vnet"
$VMVNetAddressPrefix = "172.16.0.0/16" # Only be used on new VNet
$VMSubNetName = "default"
$VMSubNetAddressPrefix = "172.16.3.0/24" # Only be used on new SubNet

$VMPIPName = $VMName + "-PIP"
$VMDNSNameLabel = $VMName.ToLower() # mydnsname.westus.cloudapp.azure.com / Put's VMName as DNS Label

$VMNSGName = $VMName + "-NSG"
$VMNSGRules = @(@("Inbound", "1000","Allow","DefaultRDP","3389"), `
                @("Inbound", "1100","Allow","DefaultSSH","22"))
#                @("Outbound","1000","Deny", "DefaultHttp","80"))
$VMNicName = $VMName + "-NIC01"

## OS Data
# Credentials for Local Admin account you created in the sysprepped (generalized) vhd image
$VMLocalAdminUser = "adminazure"
$VMLocalAdminSecurePassword = ConvertTo-SecureString "AdminAzure!1" -AsPlainText -Force
$VMCredentials = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

# Host and Storage
$VMHostName = $VMName
$OSDiskName = $newcomputername+"-OSDisk"
$DataDiskName = $newcomputername+"-DataDisk"

##### End - Change variables accordantly to your data ###########

Write-Host "`n######### Starting resources creation\validation #########" -ForegroundColor Yellow

### Create Networking
## VNet and SubNet
$VNet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName `                                  -Name $VMVNetName `                                  -ErrorAction SilentlyContinue
If ($VNet -eq $null) 
{ #Create VNet and SubNet
    Write-Host "`nCreating new VNet.................<$VMVNetName>" -ForegroundColor Yellow
    Write-Host   "Creating new SubNet...............<$VMSubNetName>" -ForegroundColor Yellow
    $SubNet = New-AzureRmVirtualNetworkSubnetConfig -Name $VMSubNetName `                                                    -AddressPrefix $VMSubNetAddressPrefix
    $VNet = New-AzureRmVirtualNetwork -ResourceGroupName $RGName `                                      -Location $LocationName `                                      -Name $VMVNetName `                                      -AddressPrefix $VMVNetAddressPrefix `                                      -Subnet $SubNet
    $VNet = Get-AzureRmVirtualNetwork -ResourceGroupName $RGName `                                      -Name $VMVNetName `
                                      -ErrorAction SilentlyContinue
    $SubNet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNet `                                                    -Name $VMSubNetName `
                                                    -ErrorAction SilentlyContinue
} else 
{ #Use existing VNet
    Write-Host "`nUsing existing VNet...............<$VMVNetName>" -ForegroundColor Yellow
    $SubNet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNet `
                                                    -Name $VMSubNetName `
                                                    -ErrorAction SilentlyContinue
    if ($SubNet -eq $null)
    { # Create SubNet
        Write-Host   "Creating new SubNet...............<$VMSubNetName>" -ForegroundColor Yellow
        $SubNet = New-AzureRmVirtualNetworkSubnetConfig -Name $VMSubNetName `
                                                        -AddressPrefix $VMSubNetAddressPrefix
        Add-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNet `
                                              -Name $VMSubNetName `
                                              -AddressPrefix $VMSubNetAddressPrefix
        $VNet | Set-AzureRmVirtualNetwork
        $SubNet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNet `
                                                        -Name $VMSubNetName `
                                                        -ErrorAction SilentlyContinue
    } else
    {
        Write-Host   "Using existing SubNet.............<$VMSubNetName>" -ForegroundColor Yellow
    } 
}

## Public IP
$PIP = Get-AzureRmPublicIpAddress -ResourceGroupName $RGName -Name $VMPIPName -ErrorAction SilentlyContinue
if ($PIP -eq $null)
{ # Create PIP
    Write-Host "`nCreating new Public IP............<$VMPIPName>" -ForegroundColor Yellow
    New-AzureRmPublicIpAddress -ResourceGroupName $RGName `
                               -Location $LocationName `
                               -Name $VMPIPName `
                               -AllocationMethod Dynamic `
                               -DomainNameLabel $VMDNSNameLabel
    $PIP = Get-AzureRmPublicIpAddress -ResourceGroupName $RGName -Name $VMPIPName -ErrorAction SilentlyContinue
} else
{ # Check if it's free to use
    if ($PIP.IpConfiguration -ne $null)
    { # PublicIP Associated
        if (!($PIP.IpConfiguration.Id).Contains($VMNicName))
        {
            Write-Host "`n######### ERROR - PROCESS CANCELED !!! #########" -ForegroundColor Red
            Write-Host   "Public IP associated other NIC....<$VMPIPName>" -ForegroundColor Yellow
            Write-Host   "Associated with <$($PIP.IpConfiguration.Id)>" -ForegroundColor Yellow
            Write-Host   "Exiting"
            Throw
        } else
        {
            Write-Host "`nUsing Public IP already associat..<$VMPIPName>" -ForegroundColor Yellow
        }
    } else
    {
        Write-Host "`nUsing existing Public IP..........<$VMPIPName>" -ForegroundColor Yellow
    }
}

## NSG
$NSG = Get-AzureRmNetworkSecurityGroup  -ResourceGroupName $RGName -Name $VMNSGName -ErrorAction SilentlyContinue
if ($NSG -eq $null)
{ # Create NSG
    $Rules = @()
    foreach ($Rule in $VMNSGRules)
    {
        $Rules += New-AzureRmNetworkSecurityRuleConfig -Name ($Rule[3]) `
                                                       -Description ($Rule[3]) `
                                                       -Access ($Rule[2]) `
                                                       -Protocol * `
                                                       -Direction ($Rule[0]) `
                                                       -Priority ($Rule[1]) `
                                                       -SourceAddressPrefix * `
                                                       -SourcePortRange * `
                                                       -DestinationAddressPrefix * `                                                       -DestinationPortRange ($Rule[4])
    } 

    Write-Host "`nCreating new NSG..................<$VMNSGName>" -ForegroundColor Yellow
    $NSG = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RGName `
                                           -Location $LocationName `                                           -Name $VMNSGName `
                                           -SecurityRules $Rules
    $NSG = Get-AzureRmNetworkSecurityGroup  -ResourceGroupName $RGName -Name $VMNSGName -ErrorAction SilentlyContinue
} else
{ # Warning: NSG Name will be used. Check if all rules are met
    Write-Host "`nUsing existing NSG................<$VMNSGName>" -ForegroundColor Yellow
    Write-Host   "     CHECK if all rules apply on existing NSG!" -ForegroundColor Red
    Write-Host   "     Rules that must exists:" -ForegroundColor Yellow
    Write-Host   "        " $VMNSGRules  -ForegroundColor Yellow
}

## NIC
$NIC = Get-AzureRmNetworkInterface -ResourceGroupName $RGName -Name $VMNicName -ErrorAction SilentlyContinue
if ($NIC -eq $null)
{ # Create NIC
    Write-Host "`nCreating new NIC..................<$VMNicName>" -ForegroundColor Yellow
    $NIC = New-AzureRmNetworkInterface -ResourceGroupName $RGName `
                                   -Location $LocationName `
                                   -Name $VMNicName `
                                   -SubnetId $SubNet.Id `
                                   -PublicIpAddressId $PIP.Id `
                                   -NetworkSecurityGroupId $NSG.Id
    $NIC = Get-AzureRmNetworkInterface -ResourceGroupName $RGName -Name $VMNicName
} else
{ # Check if that NIC is free to use
    if ($NIC.VirtualMachine -ne $null)
    { # If not free then exit with error
        Write-Host "`n######### ERROR - PROCESS CANCELED !!! #########" -ForegroundColor Red
        Write-Host   "NIC is not free...................<$VMNicName>" -ForegroundColor Yellow
        Write-Host   "Attached to <$($NIC.VirtualMachine.Id)>" -ForegroundColor Yellow
        Write-Host   "Exiting"
        Throw
    } else
    {
        Write-Host "`nUsing existing NIC................<$VMNicName>" -ForegroundColor Yellow
    }
}

### Create VM
## Get Managed VM Image 
$VMImage = $null
$VMImage = Get-AzureRmImage -ResourceGroupName $RGNameImg `
                            -ImageName $VMImageName `
                            -ErrorAction SilentlyContinue
if ($VMImage -eq $null)
{
    Write-Host "`n######### ERROR - PROCESS CANCELED !!! #########" -ForegroundColor Red
    Write-Host   "Managed VM Image not found........<$RGName>-<$VMImageName>" -ForegroundColor Yellow
    Write-Host   "Exiting"
    Throw
} else
{
    Write-Host "`nUsing existing VM Image...........<$RGNameImg>-<$VMImageName>" -ForegroundColor Yellow
}

## Create VM Config
$VM = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize 
Set-AzureRmVMOperatingSystem -VM $VM `
                             -Windows `
                             -ComputerName $VMHostName `
                             -Credential $VMCredentials `
                             -ProvisionVMAgent `
                             -EnableAutoUpdate
Add-AzureRmVMNetworkInterface -VM $VM -Id $NIC.Id

## Diagnostics
$VM.DiagnosticsProfile = New-Object -TypeName 'Microsoft.Azure.Management.Compute.Models.DiagnosticsProfile'
$VM.DiagnosticsProfile.BootDiagnostics = New-Object -TypeName 'Microsoft.Azure.Management.Compute.Models.BootDiagnostics'

# Diagnostics Off
$VM.DiagnosticsProfile.BootDiagnostics.Enabled = $false
Write-Host "`nBoot Diagnostics Disabled............." -ForegroundColor Yellow

<#
# Diagnostics On
$VM.DiagnosticsProfile.BootDiagnostics.Enabled = $true
$VM.DiagnosticsProfile.BootDiagnostics.StorageUri = $VMSADiagnosticsUri
#>


## OS Disk
Set-AzureRmVMSourceImage -VM $VM `
                         -Id ($VMImage.Id) 
Set-AzureRmVMOSDisk -VM $VM `
                    -Name $VMOSDiskName `
                    -CreateOption FromImage 

## Data Disk
$DataDisks = $VMImage.StorageProfile.DataDisks # There might be a collection of data disks
foreach ($DataDisk in $DataDisks)
{
    $DiskName = ($VMDataDiskNamePrefix + ($DataDisk.Lun + 1))
    Add-AzureRmVMDataDisk -VM $VM `
                          -Name $DiskName `
                          -CreateOption FromImage `
                          -Lun ($DataDisk.Lun) `
                          -Caching $VMDataDiskCaching 
}

New-AzureRmVM -ResourceGroupName $RGName -Location $LocationName -VM $VM -DisableBginfoExtension
Write-Host "`nVM created........................<$RGName>-<$VMName>" -ForegroundColor Yellow
Write-Host "`n######### VM Creation Completed #########" -ForegroundColor Yellow
