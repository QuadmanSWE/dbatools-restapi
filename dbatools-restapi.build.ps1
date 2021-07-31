##Requires -Module invokebuild
param(
    $name = 'dbatools-restapi',
    $dockerTag = 'latest',
    $port = 8080
)

$dockImageName = "$($name):$($dockerTag)"

task StopContainer {
    docker stop $name
}

task RemoveContainer {
    docker rm $name
}

task BuildImage {
    docker build --tag $dockImageName .
}

task RunContainer {
    docker run -d --name $name -p "$($port):8080" $dockImageName
}


task . StopContainer, RemoveContainer, BuildImage, RunContainer