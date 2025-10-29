#Stores a hashtable of our dbatools input
$splat = @{
    SqlInstance   = $env:DB_SERVICENAME
    Database      = $env:DB_NAME
    SqlCredential = (New-Object PSCredential $env:SA_USER, ($env:MSSQL_SA_PASSWORD | ConvertTo-SecureString -AsPlainText -Force))
}
$snapshotsuffix = $env:SNAPSHOTSUFFIX

#Messages we want to reuse
$errormessage = 'errors logged, check /Errors'
$welcomemessage = 'Hello, docs are available at /openapi, and you can use swagger at /swagger'

Start-PodeServer -Threads 1 {
    Set-DbatoolsInsecureConnection

    # Log messages are written to a file, the content of each logfile can be accessed on /errors
    New-PodeLoggingMethod -File -Name 'errors' -Path '/usr/src/app/logs' | Enable-PodeErrorLogging -Levels Error, Warning, Informational, Verbose
    "Logging set up!" | Write-PodeErrorLog -Level 'Informational'

    #this is why we are here
    Import-Module -Name dbatools -Force;
    (Get-Module dbatools).Version.toString() | Write-PodeErrorLog -Level 'Informational'
    
    #put the http ingress on the same port that you expose in the docker file
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    #Region utility and debugging methods
    Function Get-DatabaseExists {
        param (
            [string]$SqlInstance,
            [string]$Database,
            [PSCredential]$SqlCredential
        )
        "getting database $Database from $SqlInstance" | Write-PodeErrorLog -Level 'Verbose'
        $dbs = Get-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -ExcludeSystem
        return ([bool]$dbs)
    }   
    
    Add-PodePage -Name 'Ping' -ScriptBlock { $val = Test-Connection -ComputerName $env:DB_SERVICENAME -tcpport $env:DB_INTERNALPORT -ea 0; "sql port $($env:DB_INTERNALPORT) netconnection: [$val]"; }

    Add-PodePage -Name 'Errors' -ScriptBlock { gci /usr/src/app/logs | gc | out-string }

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeTextResponse -Value $using:welcomemessage
    }

    Add-PodeRoute -Method Get -Path '/DebugConfig' -ScriptBlock {
        Write-PodeJsonResponse -Value ($using:splat)
    }
    #EndRegion

    #Region business end methods
    Add-PodeRoute -Method Get -Path '/DatabaseExists' -ScriptBlock {
        "running /DatabaseExists" | Write-PodeErrorLog -Level 'Verbose'
        $getdbSplat = ($using:splat).Clone()
        Write-PodeTextResponse -Value (Get-DatabaseExists @getdbSplat)
    }

    Add-PodeRoute -Method Get -Path '/CreateDatabase' -ScriptBlock {
        try {
            "running /CreateDatabase" | Write-PodeErrorLog -Level 'Verbose'
            if (Get-DatabaseExists @using:splat) {
                if (Get-DbaDbSnapshot @using:splat) {
                    Remove-DbaDbSnapshot @using:splat -confirm:$false 
                }
                Remove-DbaDatabase @using:splat -Confirm:$false 
            }
            New-DbaDatabase @using:splat -ea 1 | out-null
            Write-PodeTextResponse -Value 'OK'
        }
        catch {
            $_ | Write-PodeErrorLog
            Write-PodeTextResponse -Value $using:errormessage
        }
    }

    Add-PodeRoute -Method Get -Path '/DropDatabase' -ScriptBlock {
        try {
            if (Get-DbaDbSnapshot @using:splat) {
                Remove-DbaDbSnapshot @using:splat -Confirm:$false 
            }
            Remove-DbaDatabase @using:splat -Confirm:$false 
            Write-PodeTextResponse -Value 'OK'
        }
        catch {
            $_ | Write-PodeErrorLog
            Write-PodeTextResponse -Value $using:errormessage
        }
    }

    Add-PodeRoute -Method Get -Path '/SnapshotDatabase' -ScriptBlock {
        try {
            if (Get-DbaDbSnapshot @using:splat) {
                Remove-DbaDbSnapshot @using:splat -Confirm:$false 
            }
            New-DbaDbSnapshot @using:splat -Name "$(($using:splat).Database)$($using:snapshotsuffix)" -Force -wa 1 #when going from dbatools running on linux to a sql server hosted on windows, dbatools gets confused about the path of the snapshot backup.
            Write-PodeTextResponse -Value 'OK'
        }
        catch {
            $_ | Write-PodeErrorLog
            Write-PodeTextResponse -Value $using:errormessage
        }
    }

    Add-PodeRoute -Method Get -Path '/RestoreDatabase' -scriptblock {
        try {
            if (Get-DbaDbSnapshot @using:splat) {
                Restore-DbaDbSnapshot @using:splat -Force
                Write-PodeTextResponse -Value 'OK'
            }
            else {
                Write-PodeTextResponse -Value 'No snapshot to restore from'
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            Write-PodeTextResponse -Value $using:errormessage
        }
    }
    Add-PodeRoute -Method Post -Path '/RunSqlQuery' -ScriptBlock {
        $queryString = $WebEvent.Data.Query
        try {
            Invoke-DbaQuery @using:splat -Query $queryString
            Write-PodeTextResponse -Value 'OK'
        }
        catch {
            $_ | Write-PodeErrorLog
            Write-PodeTextResponse -Value $using:errormessage
        }
        
    } -PassThru |
        Set-PodeOARouteInfo -Tags 'Queries' -PassThru |
        Set-PodeOaRequest -RequestBody (
            New-PodeOARequestBody -Required -ContentSchemas @{
                'application/json' = (New-PodeOAObjectProperty -Properties @(
                    (New-PodeOAStringProperty -Name 'Query')
                ))
            }
        )
        #Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Reference 'QueryStringBody')

    #EndRegion

    #Region Documentation
    Enable-PodeOpenApi -Title 'dbatools-restapi'
    Add-PodeOAInfo -Title 'dbatools-restapi' -Description 'Abstract database lifecycle managent to an http client' -ContactName 'David Söderlund' -ContactEmail 'ds@dsoderlund.consulting' -ContactUrl 'https://dsoderlund.consulting/'
    Enable-PodeOAViewer -Type Swagger
    #EndRegion Documentation
}