# escape=`

FROM node:18-windowsservercore-ltsc2022 AS base
SHELL ["powershell", "-Command", "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue';"]

# git（MinGit）だけ入れる（nodeは既に入ってる）
ENV GIT_VERSION 2.17.1
ENV GIT_TAG v${GIT_VERSION}.windows.1
ENV GIT_DOWNLOAD_URL https://github.com/git-for-windows/git/releases/download/${GIT_TAG}/MinGit-${GIT_VERSION}-64-bit.zip
ENV GIT_TERMINAL_PROMPT 0

RUN Invoke-WebRequest -Uri $env:GIT_DOWNLOAD_URL -OutFile 'git.zip'; `
    Expand-Archive -Path git.zip -DestinationPath C:\git\.; `
    Remove-Item git.zip -Force; `
    $env:PATH = 'C:\git\cmd;C:\git\mingw64\bin;C:\git\usr\bin;' + $env:PATH; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine); `
    git --version; node -v; npm -v

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
