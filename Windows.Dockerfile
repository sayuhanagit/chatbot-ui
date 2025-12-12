# escape=`

# =========================
# Base (Git + Node)
# =========================
ARG WINDOWS_IMAGE=mcr.microsoft.com/windows/servercore:ltsc2022
FROM ${WINDOWS_IMAGE} AS base

SHELL ["powershell", "-Command", "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue';"]

# --- MinGit (git clone用) ---
ENV GIT_VERSION 2.17.1
ENV GIT_TAG v${GIT_VERSION}.windows.1
ENV GIT_DOWNLOAD_URL https://github.com/git-for-windows/git/releases/download/${GIT_TAG}/MinGit-${GIT_VERSION}-64-bit.zip
ENV GIT_DOWNLOAD_SHA256 668d16a799dd721ed126cc91bed49eb2c072ba1b25b50048280a4e2c5ed56e59
ENV GIT_TERMINAL_PROMPT 0

RUN Write-Host ('Downloading {0} ...' -f $env:GIT_DOWNLOAD_URL); `
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; `
    Invoke-WebRequest -Uri $env:GIT_DOWNLOAD_URL -OutFile 'git.zip'; `
    Expand-Archive -Path git.zip -DestinationPath C:\git\.; `
    Remove-Item git.zip -Force; `
    $env:PATH = 'C:\git\cmd;C:\git\mingw64\bin;C:\git\usr\bin;' + $env:PATH; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine); `
    git --version;

# --- Node.js (Windows MSIで導入) ---
# chatbot-uiはNode 18系が無難（必要なら 20 に変えてOK）
ARG NODE_VERSION=18.20.4
ENV NODE_MSI_URL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-x64.msi

RUN Write-Host ('Downloading {0} ...' -f $env:NODE_MSI_URL); `
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; `
    Invoke-WebRequest -Uri $env:NODE_MSI_URL -OutFile 'node.msi'; `
    Start-Process msiexec.exe -ArgumentList @('/i','node.msi','/qn','/norestart') -Wait; `
    Remove-Item node.msi -Force; `
    node -v; npm -v;

# =========================
# Build stage (clone + npm build)
# =========================
FROM base AS build

ARG REPO_URL=https://github.com/sayuhanagit/chatbot-ui.git
ARG REPO_REF=main

WORKDIR C:\src

RUN git clone --depth 1 --branch $env:REPO_REF $env:REPO_URL app

WORKDIR C:\src\app

# 依存インストール → ビルド
# lockfileがあるなら npm ci のほうが安定
RUN if (Test-Path package-lock.json) { npm ci } else { npm install }
RUN npm run build

# =========================
# Runtime stage
# =========================
FROM base AS runtime
WORKDIR C:\app

# build成果物をコピー
COPY --from=build C:\src\app C:\app

EXPOSE 3000

# 本番起動（Next.js想定）
CMD ["powershell", "-NoLogo", "-NoProfile", "-Command", "npm run start"]
