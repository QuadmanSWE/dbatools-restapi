FROM mcr.microsoft.com/powershell:latest

RUN pwsh -c 'Install-Module Pode -Force -MinimumVersion 2.12.1'
RUN pwsh -c 'Install-Module dbatools -Force -MinimumVersion 2.1.0'

EXPOSE 8080
CMD [ "pwsh", "-c", "cd /usr/src/app; ./StartPodeServer.ps1" ]

COPY ./src/StartPodeServer.ps1 /usr/src/app/