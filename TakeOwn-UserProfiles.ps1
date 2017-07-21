<#
.SYNOPSIS
    Changes owner of user profile directories to work with Folder Redirection.
.DESCRIPTION
    This script will take input parameters for a folder and a domain name. The script will enumerate user profiles, redirected folders and roaming profiles
    from the path and update the owner on the objects. For Folder Redirection and other user file centralisation techniques to work, the user must be the owner
    of the objects. When migrating from a legacy domain, the owner will need to be updated to the new user.

    The Verbose parameter will output all of the user and path mappings as they are processed.

    The new domain name should be entered using the NetBIOS domain name.
.NOTES
Author:  Richard J Green
Version: 0.1
Date:    21th July 2017
.LINK
    https://richardjgreen.net
.EXAMPLE
    TakeOwn-UserProfiles.ps1 -SearchBase "D:\Files" -NewDomain "DomainB"
    TakeOwn-UserProfiles.ps1 -SearchBase "D:\Files" -NewDomain "DomainB" -Verbose
#>

Param(
    # Parameter for the Search Base. This is the root folder path.
    [Parameter(Mandatory=$true)]
    [string]$SearchBase,
    # Parameter for the new domain name.
    [Parameter(Mandatory=$true)]
    [string]$NewDomain
)

# Map the input parameters to objects.
$basePath = $SearchBase

# Import the NTFS Security PowerShell Module
Try {
    Import-Module NTFSSecurity
} Catch {
    Write-Error "The NTFS Security PowerShell Module could not be imported. Please check that it is installed."
    Exit
}

$children = Get-ChildItem -Path $basePath -Directory

ForEach ($child in $children) {

    $childPath = $child.FullName
    $userFolder = $child.Name
    $accountName = "$NewDomain\$userFolder"
    
    Write-Verbose "Matched Profile for $accountName at $childPath."

    # Set the user as the NTFS Owner on their own top-level folder.
    Try {
        Set-NTFSOwner -Path $childPath -Account $accountName
        Write-Verbose "Set $accountName as the owner for $childPath."
    } Catch {
        Write-Warning "Failed to modify the NTFS Owner for path $childPath to $accountName."
    }

    # Get the child folders (AppData, Documents etc)
    $grandChildren = Get-ChildItem -Path $childPath -Directory

    # Set the user as the NTFS Owner on the children of their top-level folder.
    ForEach ($grandChild in $grandChildren) {

        $grandChildPath = $grandChild.FullName
        Try {
            Set-NTFSOwner -Path $grandChildPath -Account $accountName
            Write-Verbose "Set $accountName as the owner for $grandChildPath."
        } Catch {
            Write-Warning "Failed to modify the NTFS Owner for the grand child $grandChildPath to $accountName."
        }

    }

}