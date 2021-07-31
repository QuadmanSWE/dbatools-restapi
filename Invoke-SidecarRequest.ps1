<#
.SYNOPSIS
Calls the dbatools-restapi for a method invocatino

.DESCRIPTION
Calls the dbatools-restapi for a method invocatino

.PARAMETER MethodName
One of the commands for the service, run without a command to see a list of commands

.PARAMETER Uri
Set this if you have changed any default value.
Defaults to http://localhost:8080/

.EXAMPLE
Invoke-SidecarRequest

Shows welcome messagem lists commands

.EXAMPLE
Invoke-SidecarRequest 'Ping'

Runs Test-Connection on the sql instance from the sidecar to make sure there is connectivity

.EXAMPLE
Invoke-SidecarRequest 'CreateDatabse'

(Re)creates the database that was specified in the configuration

.EXAMPLE
Invoke-SidecarRequest 'SnapshotDatabase'

(Re)creates a database snapshot of the database

.EXAMPLE
Invoke-SidecarRequest 'RestoreDatabase'

Restores the latest snapshot of the database 

.EXAMPLE
Removes the database and any snapshot

.NOTES
General notes
#>
Function Invoke-SidecarRequest {
    [CmdletBinding()]
    param(
        [string]$MethodName,
        [string]$Uri = 'http://localhost:8080'
    )
    Write-Verbose "Calling restmethod [$MethodName] on endpoint [$Uri]"
    return Invoke-Restmethod -uri "$Uri/$MethodName" -TimeoutSec 60
}