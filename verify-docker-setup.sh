#!/bin/bash

echo "=== Jenkins Docker配置验证脚本 ==="

# 检查Docker socket挂载
echo "1. 检查Docker socket挂载..."
if [ -S /var/run/docker.sock ]; then
    echo "✅ Docker socket已挂载"
    ls -la /var/run/docker.sock
else
    echo "❌ Docker socket未挂载"
    exit 1
fi

# 检查Docker客户端
echo "2. 检查Docker客户端..."
if command -v docker &> /dev/null; then
    echo "✅ Docker客户端已安装"
    docker --version
else
    echo "❌ Docker客户端未安装"
    echo "请选择以下解决方案之一："
    echo "  - 方案1: 重新创建Jenkins容器（推荐）"
    echo "  - 方案2: 在现有容器中安装Docker客户端"
    echo "  - 方案3: 使用Docker agent（已在Jenkinsfile中配置）"
    exit 1
fi

# 测试Docker权限
echo "3. 测试Docker权限..."
if docker ps &> /dev/null; then
    echo "✅ Docker权限正常"
    docker ps --format "table {{.Names}}\t{{.Status}}"
else
    echo "❌ Docker权限不足"
    echo "当前用户: $(whoami)"
    echo "用户组: $(groups)"
    exit 1
fi

# 检查docker-compose
echo "4. 检查docker-compose..."
if command -v docker-compose &> /dev/null; then
    echo "✅ docker-compose已安装"
    docker-compose --version
elif docker compose version &> /dev/null; then
    echo "✅ docker compose (v2)已安装"
    docker compose version
else
    echo "⚠️ docker-compose未安装，但可以使用Docker agent"
fi

# 测试镜像拉取
echo "5. 测试镜像拉取..."
if docker pull hello-world:latest &> /dev/null; then
    echo "✅ 可以拉取Docker镜像"
    docker rmi hello-world:latest &> /dev/null
else
    echo "❌ 无法拉取Docker镜像"
    exit 1
fi

echo ""
echo "🎉 Docker配置验证完成！"
echo ""
echo "如果所有检查都通过，您可以："
echo "1. 在Jenkins Script Console中测试: 'docker --version'.execute().text"
echo "2. 运行Jenkins Pipeline测试Docker功能"
echo ""
echo "如果有检查失败，请参考JENKINS_SETUP.md中的解决方案"
