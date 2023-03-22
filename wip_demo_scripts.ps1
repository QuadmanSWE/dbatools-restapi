
#docker-compose build


invoke-build ci
invoke-build BuildImage
invoke-build UpdateVersion

docker images dbatools-restapi

docker-compose up -d

. .\Invoke-SidecarRequest.ps1

Invoke-SidecarRequest 'ping'
Invoke-SidecarRequest 'createdatabase'
Invoke-SidecarRequest 'snapshotdatabase'
Invoke-SidecarRequest 'databaseexists'
Invoke-SidecarRequest 'restoredatabase'
Invoke-SidecarRequest 'dropdatabase'


docker-compose down


docker images