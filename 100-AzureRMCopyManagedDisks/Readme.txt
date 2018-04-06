Overview :
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
			-RGName "<ResourceGroup" `
			-DiskName "<ManageDisk/Snapshot/Name>" `
			-ToURI "<TargetURI>" `
			-ToSAS "<TargetSASContainer>" 
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
	
