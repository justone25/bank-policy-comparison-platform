# Jenkins with Docker client
FROM jenkins/jenkins:lts

# 切换到root用户安装Docker客户端
USER root

# 安装Docker客户端
RUN apt-get update && \
    apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# 安装Maven和Node.js
RUN apt-get update && \
    apt-get install -y maven nodejs npm && \
    rm -rf /var/lib/apt/lists/*

# 将jenkins用户添加到docker组
RUN groupadd -f docker && usermod -aG docker jenkins

# 切换回jenkins用户
USER jenkins

# 安装常用Jenkins插件
RUN jenkins-plugin-cli --plugins \
    pipeline-stage-view \
    docker-workflow \
    nodejs \
    email-ext \
    build-timeout \
    timestamper \
    github \
    git
