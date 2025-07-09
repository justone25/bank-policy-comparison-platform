#!/bin/bash
set -e

echo "=== 监管合规智能系统开发环境启动 ==="
echo "时间: $(date)"
echo "Java版本: $(java -version 2>&1 | head -1)"
echo "工作目录: $(pwd)"
echo "JVM参数: ${JAVA_OPTS}"
echo "调试参数: ${DEBUG_OPTS}"
echo "Spring配置: ${SPRING_PROFILES_ACTIVE}"
echo "================================================="

# 检查是否有源码挂载（开发模式）
if [ -f "pom.xml" ]; then
    echo "检测到源码挂载，使用开发模式..."

    # 检查是否需要重新编译
    if [ ! -f "gateway/target/*.jar" ] || [ "gateway/src" -nt "gateway/target" ]; then
        echo "开始Maven编译..."
        mvn clean package -pl gateway -am -DskipTests -q
    fi

    # 查找最新的JAR文件
    JAR_FILE=$(find gateway/target -name "*.jar" -not -name "*sources.jar" -not -name "*javadoc.jar" | head -1)
else
    echo "使用预构建JAR文件..."
    JAR_FILE=$(find target -name "*.jar" | head -1)
fi

if [ -z "$JAR_FILE" ]; then
    echo "错误: 未找到JAR文件"
    exit 1
fi

echo "使用JAR文件: $JAR_FILE"

# 等待依赖服务就绪
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3

    echo "等待 $service 服务启动..."
    while ! nc -z $host $port; do
        echo "等待 $service ($host:$port) 启动..."
        sleep 3
    done
    echo "$service 已就绪"
}

# 检查所有依赖服务
wait_for_service "${DB_HOST:-postgres}" "${DB_PORT:-5432}" "PostgreSQL"
wait_for_service "${REDIS_HOST:-redis}" "${REDIS_PORT:-6379}" "Redis"
wait_for_service "${ELASTICSEARCH_HOST:-elasticsearch}" "${ELASTICSEARCH_PORT:-9200}" "Elasticsearch"
wait_for_service "${RABBITMQ_HOST:-rabbitmq}" "${RABBITMQ_PORT:-5672}" "RabbitMQ"

echo "所有依赖服务已就绪，启动应用..."

# 启动应用
exec java $JAVA_OPTS $DEBUG_OPTS -jar "$JAR_FILE" --spring.profiles.active=$SPRING_PROFILES_ACTIVE