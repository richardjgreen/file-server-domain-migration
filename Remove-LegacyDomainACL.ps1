<#
.SYNOPSIS
    Script to remove all legacy domain permissions from file server ACLs.
.DESCRIPTION
    This script takes input parameters for root path and legacy domain name. Once provided, the script will recursively search
    the ACL on files and folders in that path for permissions matching the legacy domain name. Once found, they will be removed.
    Orphaned and unresolvable SIDs will also be purged from the ACL.

    The legacy domain name should be entered using the NetBIOS domain name.

    IMPORTANT: Verify that all configured Active Directory trusts are operational before running this script. If ACEs are present for users or groups
    in trusted domains and the trust is non-operational, the SID will be unresolvable and therefore removed from the ACL.
.NOTES
Author:  Richard J Green
Version: 0.5
Date:    18th July 2017
.LINK
    https://richardjgreen.net
.EXAMPLE
    Remove-LegacyDomainACL.ps1 -SearchBase "D:\Files" -LegacyDomain "DomainA"
#>

Param(
    # Parameter for the Search Base. This is the root folder path.
    [Parameter(Mandatory=$true)]
    [string]$SearchBase,
    # Parameter for the legacy domain name.
    [Parameter(Mandatory=$true)]
    [string]$LegacyDomain
)

# Map the input parameters to objects.
$basePath = $SearchBase
$domain = "$LegacyDomain\*"

# Import the NTFS Security PowerShell Module
Try {
    Import-Module NTFSSecurity
} Catch {
    Write-Error "The NTFS Security PowerShell Module could not be imported. Please check that it is installed."
    Exit
}

#region Top-Level Folder

# Get the top-level folder only.
$topFolder = Get-Item -Path $basePath

# Get the ACL on the top-level folder.
$topFolderPath = $topFolder.FullName
$acl = $topFolder | Get-NTFSAccess -ExcludeInherited

# Enumerate the ACEs on the top-level folder for legacy domain entries.
ForEach ($ace in $acl) {

    # Clean up orphaned and unresolvable SIDs.
    Get-NTFSOrphanedAccess -Path $topFolder | Remove-NTFSAccess

    # If an ACE is found containing the legacy domain name, remove it.
    If ($ace.Account.AccountName -like $domain) {
        # Capture the account name.
        $aceAccount = $ace.Account.AccountName

        Write-Information "Found legacy domain permission on $topFolderPath for user account $aceAccount."

        # Attempt to remove the ACE.
        Try {
            Get-NTFSAccess -Path $topFolder -Account $aceAccount -ExcludeInherited | Remove-NTFSAccess
        } Catch {
            Write-Warning "Failed to modify the ACE for folder $topFolderPath, for user $aceAccount."
        }
    } Else {
            # Write a debug message if there was no legacy domain ACE found on the file.
            Write-Information "No legacy domain permissions found on $topFolderPath."
    }
}          

#endregion

#region Top-Level Files

# Get the top-level files only.
$topFiles = Get-ChildItem -Path $basePath -File

# Get the ACL on each of the top-level files.
ForEach ($topFile in $topFiles) {
    $topFilePath = $topFile.FullName
    $acl = $topFile | Get-NTFSAccess -ExcludeInherited
    
    # Enumerate the ACEs on the top-level files for legacy domain entries.
    ForEach ($ace in $acl) {

        # Clean up orphaned and unresolvable SIDs.
        Get-NTFSOrphanedAccess -Path $topFilePath | Remove-NTFSAccess

        # If an ACE is found containing the legacy domain name, remove it.
        If ($ace.Account.AccountName -like $domain) {
            # Capture the account name.
            $aceAccount = $ace.Account.AccountName

            Write-Information "Found legacy domain permission on $topFilePath for user $aceAccount."

            # Attempt to remove the ACE.
            Try {
                Get-NTFSAccess -Path $topFilePath -Account $aceAccount -ExcludeInherited | Remove-NTFSAccess
            } Catch {
                Write-Warning "Failed to modify the ACE for file $topFilePath, for user $aceAccount."
            }

        } Else {
            # Write a debug message if there was no legacy domain ACE found on the file.
            Write-Information "No legacy domain permissions found on $topFilePath."
        }
    }

}

#endregion
    
#region Child Files and Folders

# Get all the child folders and files.
$children = Get-ChildItem -Path $basePath -Recurse

# Get the ACL on each file and folder.
ForEach ($child in $children) {
    $childPath = $child.FullName
    $acl = $children | Get-NTFSAccess -ExcludeInherited

    # Enumerate the ACEs on the top-level files for legacy domain entries.
    ForEach ($ace in $acl) {

        # Clean up orphaned and unresolvable SIDs.
        Get-NTFSOrphanedAccess -Path $childPath | Remove-NTFSAccess

        # If an ACE is found containing the legacy domain name, remove it.
        If ($ace.Account.AccountName -like $domain) {
            # Capture the account name.
            $aceAccount = $ace.Account.AccountName

            Write-Information "Found legacy domain permission on $childPath for user $aceAccount."

            # Attempt to remove the ACE.
            Try {
                Get-NTFSAccess -Path $childPath -Account $aceAccount -ExcludeInherited | Remove-NTFSAccess
            } Catch {
                Write-Warning "Failed to modify the ACE for file $childPath, for user $aceAccount."
            }

        } Else {
            # Write a debug message if there was no legacy domain ACE found on the file.
            Write-Information "No legacy domain permissions found on $childPath."
        }
    }

}

#endregion

