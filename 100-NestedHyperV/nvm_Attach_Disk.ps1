<# .SYNOPSIS
     Nested Virtualization for Windows Server 2016.
	 Offline Disk 3
	 Add vhd to VM as Physical disk
.DESCRIPTION
     Bootstrap Powershell Script for mounting Physical disk 
.NOTES
     Windows Server 2016 Flavor Only.
     Author     : Rafael Duarte
     Date: 9/14/2017
.LINK
     
#>

#TODO - EDIT ME! Change the Name you want for your Guest VM.
$VMName = "VM1"

#
# Need to run elevated.  Do that here.
#

Enable-PSRemoting -force

# Get the ID and security principal of the current user account
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent();
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID);

# Get the security principal for the administrator role
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;

# Check to see if we are currently running as an administrator
if ($myWindowsPrincipal.IsInRole($adminRole)) {
    # We are running as an administrator, so change the title and background colour to indicate this
    $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)";
    #$Host.UI.RawUI.BackgroundColor = "DarkBlue";

    } else {
    # We are not running as an administrator, so relaunch as administrator

    # Create a new process object that starts PowerShell
    $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";

    # Specify the current script path and name as a parameter with added scope and support for scripts with spaces in it's path
    $newProcess.Arguments = "& '" + $script:MyInvocation.MyCommand.Path + "'"

    # Indicate that the process should be elevated
    $newProcess.Verb = "runas";

    # Start the new process
    [System.Diagnostics.Process]::Start($newProcess) | Out-Null;

    # Exit from the current, unelevated, process
    Exit;
    }

# Run code that needs to be elevated here...


# Get Physical disks
"select disk 3", "offline disk" | diskpart

try {Add-VMHardDiskDrive -VMName $VMName -ControllerType IDE -ControllerNumber 0 -ControllerLocation 0 -DiskNumber 3 -ErrorAction SilentlyContinue}
catch {}

Write-Host "This script will take offline disk 2 and attach it to $vmName on Hyper-v"
Write-Host "done."

#
# Disclaimer
#

Write-Host "========================================================="
Write-Host "The Bootstrap Powershell Script has Executed Successfully." -ForegroundColor White -BackgroundColor Green
Write-Host "Thank you for using this forked custom-made bootstrap script for Windows Server 2016."
Write-Host "Team: AZURE IaaS Plaform   AUTHOR: Rafael Duarte"

