# escape=`

FROM mcr.microsoft.com/windows/servercore:ltsc2022 AS base
SHELL ["powershell", "-Command", "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue';"]

# ---------- MinGit (git clone用) ----------
ENV GIT_VERSION 2.17.1
ENV GIT_TAG v${GIT_VERSION}.windows.1
ENV GIT_DOWNLOAD_URL https://github.com/git-for-windows/git/releases/download/${GIT_TAG}/MinGit-${GIT_VERSION}-64-bit.zip
ENV GIT_DOWNLOAD_SHA256 668d16a799dd721ed126cc91bed49eb2c072ba1b25b50048280a4e2c5ed56e59
ENV GIT_TERMINAL_PROMPT 0

RUN Invoke-WebRequest -Uri $env:GIT_DOWNLOAD_URL -OutFile C:\git.zip; `
    Expand-Archive -Path C:\git.zip -DestinationPath C:\git\.; `
    Remove-Item C:\git.zip -Force; `
    $env:PATH = 'C:\git\cmd;C:\git\mingw64\bin;C:\git\usr\bin;' + $env:PATH; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine); `
    git --version

# ---------- Node.js (MSI) ----------
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
