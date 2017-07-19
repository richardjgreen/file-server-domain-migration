# file-server-domain-migration
Kit of PowerShell scripts that are extremely useful when doing File Server migration in a domain migration.

When performing a domain migration, file server migration can be one of the most technically challenging aspects. With ACLs, inheritence, file ownership, remote domain groups and all sorts to worry about.

This kit contains two PowerShell scripts. These two scripts depend on a PowerShell module, NTFSSecurity from https://github.com/raandree/NTFSSecurity. With this module and these scripts, you can easily migrate and clean-up your file server.

The first script, Migrate-DomainAcls.ps1 will review the ACL on each folder and file on the file server. When it finds a user or a group in the legacy domain, it will update the ACL with a new ACE for a matching user or group in the new domain. This is ideal if you have used ADMT to migrate the objects from the legacy to the new domain.
When it encounters file or folder without access, it uses elevated rights in PowerShell to attempt to give the server administrator group rights and re-gain access to those files. This is ideal during an interim period where old and new domains both need access to the data.

The second script, Remove-LegacyDomainAcls.ps1 will go through each file and folder on the server. It will remove any ACEs for users or groups in the legacy domain. If it finds any SIDs which are unresolvable, it will also remove these. This is great once you have done the cutover to the new domain and want to clean up post migration.

Both scripts are parameterised to make them simple to use in any environment.
