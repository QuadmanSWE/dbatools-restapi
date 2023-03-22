#Stores a hashtable of our dbatools input
$splat = @{
    SqlInstance   = $env:DB_SERVICENAME
    Database      = $env:DB_NAME
    SqlCredential = (New-Object PSCredential $env:SA_USER, ($env:SA_PASSWORD | ConvertTo-SecureString -AsPlainText -Force))
}
$snapshotsuffix = $env:SNAPSHOTSUFFIX

#Messages we want to reuse
$errormessage = 'errors logged, check /Errors'
$welcomemessage = 'Hello, this is not swagger. But you can still get some info! Commands: /Ping /Errors /DebugConfig /DatabaseExists /CreateDatabase /DropDatabase /SnapshotDatabase /RestoreDatabase'

Start-PodeServer -Threads 1 {

    #errors are written to a log file, the content of each logfile can be accessed on /errors
    New-PodeLoggingMethod -File -Name 'errors' -Path '/usr/src/app/logs' | Enable-PodeErrorLogging -Levels Error, Warning, Informational, Verbose

    #this is why we are here
    Import-PodeModule -Name dbatools;
    
    #put the http ingress on the same port that you expose in the docker file
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    #Region utility and debugging methods
    Function Get-DatabaseExists {
        param (
            [string]$SqlInstance,
            [string]$Database,
            [PSCredential]$SqlCredential
        )
        Import-Module dbatools -Force; #There seems to be a bug related to how dbatools overrides the .Query in sql server management objects and when running it inside pode where it has been loaded during pode start.
        $dbs = Get-DbaDatabase -Sqlinstance $SqlInstance -SqlCredential $SqlCredential -Database $Database
        return !($null -eq $dbs) 
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
        Write-PodeTextResponse -Value (Get-DatabaseExists @using:splat)
    }

    Add-PodeRoute -Method Get -Path '/CreateDatabase' -ScriptBlock {
        try {
            $instancesplat = ($using:splat).Clone()
            $instancesplat.Remove('Database')
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
            $instancesplat = ($using:splat).Clone()
            $instancesplat.Remove('Database')
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
    #EndRegion
}