<#
.SYNOPSIS
    Script to migrate file server permissions from one domain to another.
.DESCRIPTION
    This script takes input parameters for the base path to the file server share, the old domain name and the new domain name.
    The script will clone the permissions granted to the legacy domain users and groups and add them to the new domain users and groups.
    Legacy domain permissions are not deleted. This allows co-existence to occur.

    An optional AdminGroup parameter can be specified. When a file or folder is found and the user executing the script has no permissions, we
    will attempt to forcibly add the specified administrative group to the ACL and then retry the update. This is useful when inheritence has been 
    disabled and Domain Admins, local Administrators and other management groups have been removed.

    Using the Verbose parameter will display the mapping of all of the identities from source to target domain. It will also report the file or folder
    being processed to allow you to track the process.

    The legacy domain name should be entered using the NetBIOS domain name.
.NOTES
Author:  Richard J Green
Version: 0.5
Date:    18th July 2017
.LINK
    https://richardjgreen.net
.EXAMPLE
    Migrate-DomainACLs.ps1 -SearchBase "D:\Files" -LegacyDomain "DomainA" -NewDomain "DomainB"
    Migrate-DomainACLs.ps1 -SearchBase "D:\Files" -LegacyDomain "DomainA" -NewDomain "DomainB" -AdminGroup "Domain Admins" -Verbose
#>

Param(
    # Parameter for the Search Base. This is the root folder path.
    [Parameter(Mandatory=$true)]
    [string]$SearchBase,
    # Parameter for the legacy domain name.
    [Parameter(Mandatory=$true)]
    [regex]$LegacyDomain,
    # Parameter for the new domain name.
    [Parameter(Mandatory=$true)]
    [string]$NewDomain,
    # Optional parameter for the administrative group name in the new domain.
    [string]$AdminGroup
)

# Map the input parameters to objects.
$basePath = $SearchBase
$oldDomain = "$LegacyDomain\*"
$newDomainGroup = "$NewDomain\$AdminGroup"

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

ForEach ($ace in $acl) {

    # Parse the ACEs for those containing the legacy domain name.
    If ($ace.Account.AccountName -like $oldDomain) {
        # Capture the account name.
        $aceOldAccount = $ace.Account.AccountName
        $aceNewAccount = $LegacyDomain.Replace($aceOldAccount, $NewDomain, 1)
        $acePermission = $ace.AccessRights
        
        # Write an information message to show the old account to new account mapping.
        Write-Information "Mapped identity $aceOldAccount to $aceNewAccount"

        # Attempt to add the new ACE to the ACL for the object.
        Try {
            Add-NTFSAccess -Path $topFolderPath -Account $aceNewAccount -AccessRights $acePermission
        } Catch {
            # Attempt to add a new ACE for the specified administrative security group in the new domain.
            Try {
                Enable-Privileges
                Add-NTFSAccess -Path $childPath -Account $newDomainGroup -AccessRights FullControl
                Disable-Privileges
                # Retry adding the object ACE to the ACL after applying the admin group.
                Try {
                    Add-NTFSAccess -Path $topFolderPath -Account $aceNewAccount -AccessRights $acePermission
                } Catch {
                }
            } Catch {
                # Output warning if failed to forcibly add the administrative group permission.
                Write-Warning "Failed to forcibly add $newDomainGroup to the ACL for $childPath."
            }
                
            # Output warning for failed item.
            Write-Warning "Failed to update ACL for $childPath."

        }

    } Else {
        # Write a debug message if there was no legacy domain ACE found on the file.
        Write-Information "No legacy domain permissions found on $topFolderPath."
    }

}

#endregion

#region Child Folders and Files

# Get all the child folders and files.
$children = Get-ChildItem -Path $basePath -Recurse

ForEach ($child in $children) {
    $childPath = $child.FullName
    $acl = $child | Get-NTFSAccess -ExcludeInherited

    ForEach ($ace in $acl) {

        # Parse the ACEs for those containing the legacy domain name.
        If ($ace.Account.AccountName -like $oldDomain) {
            # Capture the account name.
            $aceOldAccount = $ace.Account.AccountName
            $aceNewAccount = $LegacyDomain.Replace($aceOldAccount, $NewDomain, 1)
            $acePermission = $ace.AccessRights
            $aceType = $ace.AccessControlType
            $aceInherit = $ace.InheritanceFlags
            $acePropagation = $ace.PropagationFlags
        
            # Write a verbose message to show the old account to new account mapping.
            Write-Verbose "Mapped identity $aceOldAccount to $aceNewAccount"

            # Write a verbose message to show the working file or folder.
            Write-Verbose "Updating ACL on $childPath."

            # Attempt to add the new ACE to the ACL for the object.
            Try {
                Add-NTFSAccess -Path $childPath -Account $aceNewAccount -AccessRights $acePermission -AccessType $aceType -InheritanceFlags $aceInherit -PropagationFlags $acePropagation
            } Catch {
                # Attempt to add a new ACE for the specified administrative security group in the new domain.
                Try {
                    Enable-Privileges
                    Add-NTFSAccess -Path $childPath -Account $newDomainGroup -AccessRights FullControl
                    Disable-Privileges
                    # Retry adding the object ACE to the ACL after applying the admin group.
                    Try {
                        Add-NTFSAccess -Path $childPath -Account $aceNewAccount -AccessRights $acePermission -AccessType $aceType -InheritanceFlags $aceInherit -PropagationFlags $acePropagation
                    } Catch {
                    }
                } Catch {
                    # Output warning if failed to forcibly add the administrative group permission.
                    Write-Warning "Failed to forcibly add $newDomainGroup to the ACL for $childPath."
                }
                
                # Output warning for failed item.
                Write-Warning "Failed to update ACL for $childPath."

            }

            } Else {
                # Write a debug message if there was no legacy domain ACE found on the file.
                Write-Information "No legacy domain permissions found on $childPath."
        }
    }
}

#endregion