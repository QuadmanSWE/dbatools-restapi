# dbatools-restapi

 Using a container with dbatools and pode server to wrap dbatools powershell cmdlets as a REST API we can abstract database lifecycle managent to an http client

 It can be run stand alone or bundled together with an sql server server container as a side car for testing.

- [dbatools-restapi](#dbatools-restapi)
  - [Insecure by default.](#insecure-by-default)
  - [SQL Server in a container with a sidecar](#sql-server-in-a-container-with-a-sidecar)
  - [Other sql server](#other-sql-server)
    - [sa account](#sa-account)
  - [Example](#example)

## Insecure by default.

in the early 2020s [Microsoft finally started to take encryption seriously](https://learn.microsoft.com/en-us/sql/connect/oledb/major-version-differences?view=sql-server-ver16) and set their defaults to encrypt traffic and for clients to not automatically trust any server certificate.

Chrissy LeMaire of dbatools [wrote a good blog post on what this means](https://blog.netnerds.net/2023/03/new-defaults-for-sql-server-connections-encryption-trust-certificate/).

For this tool, the default stays, so I added this to the pode server.

``` PowerShell
Start-PodeServer -Threads 1 {
    Set-DbatoolsInsecureConnection
# ...
}
```

I would love for someone to send a PR on allowing you to set your root cert, and to not trust but to verify in the .env file.

## SQL Server in a container with a sidecar

You can use docker compose to build and up everything in one go.

## Other sql server

You can use the docker file to run stand alone and target another server. Doing so will require you to give the container network access.

``` powershell
$ContainerName = 'standalone'
$HostPort = 8080
$ImageName = 'dsoderlund/dbatools-restapi:latest'
Invoke-Command { docker stop $ContainerName } -ErrorAction "SilentlyContinue" | Out-Null
Invoke-Command { docker rm   $ContainerName } -ErrorAction "SilentlyContinue" | Out-Null
Write-Host "Starting container $ContainerName on port $HostPort from the image $ImageName"
docker run -d --name $ContainerName -p "$($HostPort):8080" $ImageName
```

### sa account

If you are using another target server than the one created with docker-compose, you need to manually add the corresponding sa account to that instance.

``` powershell
Import-Module dbatools
# declare the variables from the file so they are in powershell.
gc .env | % {
    $n,$v = $_.Split('=')
    set-variable -Name $n -Value $v
}
# Set variables for localhost sql server sa account creation
New-DbaLogin -sqlinstance "localhost,$($DB_INTERNALPORT)" -login $SA_USER -securepassword ( $MSSQL_SA_PASSWORD | convertto-securestring -asplaintext -force ) -force | out-null

# WARNING: this allows the user from your env file to be the sysadmin of the sql instance you are targetting. Double check these settings before you run.
# - this is to allow the user to be able to create, delete, snapshot ANY database. -
# do not run this if you value the data that is inside this database instance.
Add-DbaServerRoleMember -sqlinstance "localhost,$($DB_INTERNALPORT)" -Login $SA_USER -serverrole 'sysadmin' -confirm:$false
``` 

Surf to http://localhost:8080/ in your browser to see that the site is up

``` powershell
Function Invoke-SidecarRequest {
    [CmdletBinding()]
    param(
        [string]$MethodName,
        [string]$Uri = 'http://localhost:8080'
    )
    Write-Verbose "Calling restmethod [$MethodName] on endpoint [$Uri]"
    return Invoke-Restmethod -uri "$Uri/$MethodName" -TimeoutSec 60
}
```

## Example 

Use Usage-Demo.ps1 to try out the features on top of sql server 2022 on express in docker.