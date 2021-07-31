FROM mcr.microsoft.com/powershell:latest

RUN pwsh -c 'Install-Module Pode -Force'
RUN pwsh -c 'Install-Module dbatools -Force -MinimumVersion 1.1.4'

EXPOSE 8080
CMD [ "pwsh", "-c", "cd /usr/src/app; ./StartPodeServer.ps1" ]

COPY ./src/StartPodeServer.ps1 /usr/src/app/