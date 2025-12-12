# escape=`

FROM mcr.microsoft.com/windows/servercore:ltsc2022 AS base
SHELL ["powershell", "-Command", "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue';"]

# Node.js (MSI)
ARG NODE_VERSION=18.20.4
ENV NODE_MSI_URL=https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-x64.msi

RUN Invoke-WebRequest -Uri $env:NODE_MSI_URL -OutFile C:\node.msi; `
    Start-Process msiexec.exe -ArgumentList @('/i','C:\node.msi','/qn','/norestart') -Wait; `
    Remove-Item C:\node.msi -Force; `
    $nodePath='C:\Program Files\nodejs'; `
    $env:PATH = \"$nodePath;\" + $env:PATH; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine); `
    & \"$nodePath\node.exe\" -v; `
    & \"$nodePath\npm.cmd\" -v

FROM base AS build
ARG REPO_URL=https://github.com/sayuhanagit/chatbot-ui.git
ARG REPO_REF=main
WORKDIR C:\src
RUN git clone --depth 1 --branch $env:REPO_REF $env:REPO_URL app
WORKDIR C:\src\app
RUN if (Test-Path package-lock.json) { npm ci } else { npm install }
RUN npm run build

FROM base AS runtime
WORKDIR C:\app
COPY --from=build C:\src\app C:\app
EXPOSE 3000
CMD ["powershell","-NoLogo","-NoProfile","-Command","npm run start"]
