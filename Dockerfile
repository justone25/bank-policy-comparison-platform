# =============================================================================
# 监管合规智能系统后端服务 Dockerfile
# 使用外部脚本文件的版本
# =============================================================================

# -----------------------------------------------------------------------------
# 阶段1: 构建阶段 (Builder Stage)
# -----------------------------------------------------------------------------
FROM maven:3.9.5-eclipse-temurin-17 AS builder

WORKDIR /app

# 复制Maven配置文件
COPY pom.xml ./
COPY common/pom.xml ./common/
COPY core/pom.xml ./core/
COPY nlp/pom.xml ./nlp/
COPY search/pom.xml ./search/
COPY gateway/pom.xml ./gateway/

# 下载Maven依赖
RUN mvn dependency:go-offline -B

# 复制源代码
COPY common/src ./common/src/
COPY core/src ./core/src/
COPY nlp/src ./nlp/src/
COPY search/src ./search/src/
COPY gateway/src ./gateway/src/

# 构建应用
RUN mvn clean package -pl gateway -am -DskipTests

# 验证构建结果
RUN ls -la /app/gateway/target/ && \
    find /app/gateway/target -name "*.jar" -not -name "*sources.jar" -not -name "*javadoc.jar"

# -----------------------------------------------------------------------------
# 阶段2: 开发运行阶段 (Development Stage)
# -----------------------------------------------------------------------------
FROM eclipse-temurin:17-jdk AS development

# 安装开发工具
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    vim \
    htop \
    netcat-openbsd \
    procps \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 安装Maven
ENV MAVEN_VERSION=3.9.5
ENV MAVEN_HOME=/opt/maven
ENV PATH=$PATH:$MAVEN_HOME/bin

RUN wget -q https://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz && \
    tar -xzf apache-maven-$MAVEN_VERSION-bin.tar.gz -C /opt && \
    mv /opt/apache-maven-$MAVEN_VERSION /opt/maven && \
    rm apache-maven-$MAVEN_VERSION-bin.tar.gz

# 创建必要目录
RUN mkdir -p /app/logs /app/data/files /app/target

# 复制构建产物（作为备用）
COPY --from=builder /app/gateway/target/*.jar /app/target/

# 复制启动脚本（从项目根目录）
COPY start-dev.sh /app/start-dev.sh
RUN chmod +x /app/start-dev.sh

# 设置环境变量
ENV JAVA_OPTS="-Xms512m -Xmx2g -XX:+UseG1GC -XX:MaxGCPauseMillis=100"
ENV DEBUG_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5050"
ENV SPRING_PROFILES_ACTIVE="docker"

# 暴露端口
EXPOSE 8080 5050

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# 启动命令
CMD ["/app/start-dev.sh"]

# -----------------------------------------------------------------------------
# 阶段3: 生产运行阶段 (Production Stage)
# -----------------------------------------------------------------------------
FROM eclipse-temurin:17-jre AS production

# 安装必要工具
RUN apt-get update && apt-get install -y \
    curl \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# 创建应用用户
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 设置工作目录
WORKDIR /app

# 复制JAR文件
COPY --from=builder /app/gateway/target/*.jar app.jar

# 创建必要目录并设置权限
RUN mkdir -p /app/logs /app/data/files && \
    chown -R appuser:appuser /app

# 复制生产环境启动脚本
COPY start-prod.sh /app/start-prod.sh
RUN chmod +x /app/start-prod.sh && chown appuser:appuser /app/start-prod.sh

# 切换到应用用户
USER appuser

# 设置生产环境JVM参数
ENV JAVA_OPTS="-Xms1g -Xmx4g -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/app/logs/"

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# 启动命令
CMD ["/app/start-prod.sh"]