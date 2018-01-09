List and/or install Windows Azure Guest Agent

•	Above script have different scopes:
    o	To Apply only to all Subscription:
      .\AzureRMWAgent.ps1 -subID <SubscriptionID> -logPath C:\temp [-InstallWAgent]
    o	To Apply only to a Resource Group:
      .\AzureRMWAgent.ps1 -subID <SubscriptionID> -RG <Resource Group Name> -logPath C:\temp [-InstallWAgent]
    o	To Apply only to a Virtual Machine:
      .\AzureRMWAgent.ps1 -subID <SubscriptionID> -RG <Resource Group Name> -VM <VM Name> -logPath C:\temp [-InstallWAgent]

•	This script will use another Powershell script from the public location above:
    o	https://raw.githubusercontent.com/KemTech/Azure/master/100-AzureRMWAgent/AzureRMWAgent_InstallWaga.ps1

•	Because applying CustomScripts Extension to VM’s can take some time, Is advisable to use this script by VM or Resource Group.
