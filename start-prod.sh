#!/bin/bash
set -e

echo "=== 监管合规智能系统生产环境 ==="
echo "时间: $(date)"
echo "Java版本: $(java -version 2>&1 | head -1)"
echo "应用文件: $(ls -la app.jar)"
echo "JVM参数: ${JAVA_OPTS}"
echo "======================================"

# 生产环境健康检查
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3

    echo "检查 $service 服务..."
    for i in {1..30}; do
        if nc -z $host $port; then
            echo "$service 已连接"
            return 0
        fi
        echo "等待 $service ($host:$port)... ($i/30)"
        sleep 2
    done
    echo "警告: $service 连接超时，继续启动..."
}

# 检查关键服务
wait_for_service "${DB_HOST:-postgres}" "${DB_PORT:-5432}" "PostgreSQL"
wait_for_service "${REDIS_HOST:-redis}" "${REDIS_PORT:-6379}" "Redis"
wait_for_service "${ELASTICSEARCH_HOST:-elasticsearch}" "${ELASTICSEARCH_PORT:-9200}" "Elasticsearch"

echo "启动应用程序..."
exec java $JAVA_OPTS -jar app.jar --spring.profiles.active=production