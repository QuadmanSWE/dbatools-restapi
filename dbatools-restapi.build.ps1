##Requires -Module invokebuild
param(
    $name = 'dbatools-restapi',
    $dockerTag = 'latest',
    $port = 8080,
    [switch]$NewMajor,
    [switch]$NewMinor
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

task build BuildImage

task RunContainer {
    docker run -d --name $name -p "$($port):8080" $dockImageName
}

task TagVersion {
    $newtag = "v$((gc VERSION))"
    docker tag $dockImageName "$($name):$($newtag)"
    Write-Host "Tagged as $($name):$($newtag)" -ForegroundColor Blue
}

task UpdateVersion {
    #semantic versioning.
    [int]$curMajor, [int]$curMinor, [int]$curPatch = (gc VERSION).split('.')
    
    if($NewMajor){
        $major = $curMajor+1
        $minor = 0
        $patch = 0
    }
    elseif($NewMinor){
        $major = $curMajor
        $minor = $curminor+1
        $patch = 0
    }
    else{
        $major = $curMajor
        $minor = $curMinor
        $patch = $curPatch+1
    }

    "$major.$minor.$patch" | out-file VERSION -Encoding utf8
    Write-Host "New version! [$major.$minor.$patch]" -ForegroundColor Blue
}
task bump UpdateVersion
task ci UpdateVersion, BuildImage, TagVersion
task . StopContainer, RemoveContainer, BuildImage, RunContainer