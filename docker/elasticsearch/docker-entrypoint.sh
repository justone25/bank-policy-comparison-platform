#!/bin/bash
set -e

echo "Starting Elasticsearch with IK Analyzer..."

# 简单检查IK配置文件
if [ -f "/usr/share/elasticsearch/plugins/ik/config/IKAnalyzer.cfg.xml" ]; then
    echo "Found IK Analyzer configuration file"
else
    echo "IK Analyzer configuration file not found, using default settings"
fi

# 直接启动Elasticsearch，不创建额外进程
echo "===========Starting Elasticsearch==========="
exec /usr/share/elasticsearch/bin/elasticsearch "$@"