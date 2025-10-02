# Default build
docker build -t dbatools-restapi:latest .

Push-Location .\example_implementation

# Let's make sure we are at the starting state
docker-compose down

# dot source (load) the function
. .\Invoke-SidecarRequest.ps1

# jump in and start the containers
docker-compose up -d 

#Region await desired state
Function Wait-ForContainerConnectivity {
    param(
        [string]$Uri = 'http://localhost:8080'
    )
    $connected = $false; $attempts = 0; [string]$result = $null;
    while (!$connected -and $attempts -lt 15) {
        start-sleep 2
        try {
            $result = Invoke-SidecarRequest 'Ping'
        }
        catch {
            $result = $null;
        }
        if ($result) {
            $retval = $result -match '(?<=\[)(.*?)(?=\])' #check for any value between brackets []
            if ($retval -eq 'True') {
                $connected = $true
            }
        }
        $attempts++;
    }
    if ($connected) {
        write-host "Connection to container and container connect to sql server established after [$attempts] attempts"
    }
    else {
        throw  "Could not affirm that that the container is connected to sql server after [$attempts] attempts"
    }
}
Wait-ForContainerConnectivity
#EndRegion

$ErrorActionPreference = 'Stop'

#First thing is first, I do not expect there to be a database:
Invoke-SidecarRequest 'DatabaseExists' # should be False

#create database and login
$result = Invoke-SidecarRequest 'CreateDatabase'
if ($result -ne 'OK') {
    throw $result
}

#Now there is a database right?
Invoke-SidecarRequest 'DatabaseExists' # should be True

#Create some example data

<#
``` SQL
CREATE TABLE dbo.SomeData(id int not null identity(1,1), somevalue varchar(100) NOT NULL);
INSERT INTO dbo.SomeData (somevalue) values ('Some data');
SELECT * FROM dbo.SomeData;
```
#>

#snapshot init
#We can also capture the body of the http request and handle it in powershell.
$result = Invoke-SidecarRequest 'SnapshotDatabase'
if ($result -ne 'OK') {
    throw $result
}


# Perform some integration test that might affect the database
<#
``` SQL
INSERT INTO dbo.SomeData (somevalue) values ('Some other data that we do not want to persist');
SELECT * FROM dbo.SomeData;
```
#>

# Restore the database for the next test
Invoke-SidecarRequest 'RestoreDatabase'

##
<# ``` SQL
SELECT * FROM dbo.SomeData;
``` #>

#If we want to change the snapshot we just recreate it, there is not any notion of multiple snapshots in this tool, just wether there is one or not.
Invoke-SidecarRequest 'SnapshotDatabase'


# Cleanup
#dropping the database also drops any snapshots for the database, as you might expect.
Invoke-SidecarRequest 'DropDatabase'

#You can figure out the rest
Invoke-SidecarRequest 'DatabaseExists' # should be False

# Shut it down
docker-compose down

# Jump back to where you started
Pop-Location