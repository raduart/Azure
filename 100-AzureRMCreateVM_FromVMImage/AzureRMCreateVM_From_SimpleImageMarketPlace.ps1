$LocationName = "West Europe"

# Data for New VM
$RGName = "rd2373"
$VMName = "rd2373Posh02"
$VMVNetName = "rd2373-vnet"
$VMSubNetName = "default"
$VMNSGName = $VMName + "NSG"
$VMPIPName = $VMName + "PIP"
$VMOpenPorts = "3389"
$VMLocalAdminUser = "adminazure"
$VMLocalAdminSecurePassword = ConvertTo-SecureString "AdminAzure!1" -AsPlainText -Force
$VMSize = "Standard_DS2_v2"

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

# Creates a default Windows Server 2016 from Azure Market place "SimpleParameterSet"
#$VMName = "rd2373Posh01"
New-AzureRmVm `
    -ResourceGroupName $RGName `
    -Name $VMName `
    -Location $LocationName `
    -Credential $Credential `
    -VirtualNetworkName $VMVNetName `
    -SubnetName $VMSubNetName `
    -SecurityGroupName $VMNSGName `
    -PublicIpAddressName $VMPIPName `
    -Size $VMSize `
    -OpenPorts $VMOpenPorts `
    -ImageName Win2016Datacenter
