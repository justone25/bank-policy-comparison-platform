# Jenkins配置检查清单

## ✅ 必需插件检查

- [ ] Pipeline Plugin
- [ ] Docker Pipeline Plugin  
- [ ] NodeJS Plugin
- [ ] Email Extension Plugin
- [ ] Build Timeout Plugin
- [ ] Timestamper Plugin
- [ ] Git Plugin
- [ ] GitHub Plugin

## ✅ 工具配置检查

### Maven 3.9.5配置
- [ ] 进入 `Manage Jenkins` → `Global Tool Configuration`
- [ ] 添加Maven工具，名称为：`Maven-3.9.5`
- [ ] 选择自动安装，版本：3.9.5
- [ ] 测试命令：`mvn -version`

### Node.js 20配置  
- [ ] 进入 `Manage Jenkins` → `Global Tool Configuration`
- [ ] 添加NodeJS工具，名称为：`NodeJS-20`
- [ ] 选择自动安装，版本：NodeJS 20.x.x
- [ ] 全局npm包：`npm@latest`
- [ ] 测试命令：`node --version` 和 `npm --version`

## ✅ Docker权限配置

### 方法1：添加用户到docker组（推荐）
```bash
# 1. 添加jenkins用户到docker组
sudo usermod -aG docker jenkins

# 2. 重启Jenkins服务
sudo systemctl restart jenkins

# 3. 验证权限
sudo -u jenkins docker ps
```

### 方法2：Docker socket挂载（容器化Jenkins）
```bash
# 启动Jenkins容器时挂载Docker socket
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts
```

### 验证Docker权限
- [ ] 在Jenkins Script Console中执行：
```groovy
def proc = "docker --version".execute()
proc.waitFor()
println "Exit code: ${proc.exitValue()}"
println "Output: ${proc.text}"
```

## ✅ 环境变量配置

### 系统环境变量
- [ ] 进入 `Manage Jenkins` → `Configure System` → `Global properties`
- [ ] 添加环境变量：
  - `JAVA_HOME`: Java安装路径
  - `MAVEN_HOME`: Maven安装路径（如果手动安装）
  - `DOCKER_HOST`: Docker daemon地址（如果需要）

### 项目环境变量
- [ ] 确认项目根目录有`.env`文件
- [ ] 验证.env文件格式正确（KEY=VALUE）
- [ ] 检查敏感信息是否需要使用Jenkins凭据管理

## ✅ GitHub集成配置

### GitHub仓库设置
- [ ] 进入GitHub仓库 → `Settings` → `Webhooks`
- [ ] 添加webhook：
  - URL: `http://your-jenkins-server/github-webhook/`
  - Content type: `application/json`
  - Events: `Push events`, `Pull request events`

### Jenkins项目配置
- [ ] 创建新的Pipeline项目
- [ ] Pipeline定义选择：`Pipeline script from SCM`
- [ ] SCM选择：`Git`
- [ ] Repository URL：填入GitHub仓库地址
- [ ] Branches to build：`*/main` 或 `*/*`
- [ ] Script Path：`Jenkinsfile`

## ✅ 权限和安全配置

### Jenkins用户权限
- [ ] 确认Jenkins用户有读写工作空间权限
- [ ] 确认Jenkins用户有执行shell命令权限
- [ ] 确认Jenkins用户有Docker操作权限

### 网络和防火墙
- [ ] 确认Jenkins可以访问GitHub
- [ ] 确认Jenkins可以访问Docker Hub（如果需要）
- [ ] 确认Jenkins可以访问Maven Central仓库
- [ ] 确认Jenkins可以访问npm仓库

## ✅ 测试验证

### 基础功能测试
- [ ] 运行测试Pipeline验证工具配置
- [ ] 测试GitHub webhook触发
- [ ] 测试邮件通知功能
- [ ] 测试Docker镜像构建

### 项目特定测试
- [ ] 测试Maven多模块构建
- [ ] 测试前端项目构建
- [ ] 测试Docker Compose部署
- [ ] 测试环境变量加载

## 🔧 常见问题排查

### Docker权限问题
```bash
# 检查jenkins用户组
groups jenkins

# 检查docker组成员
getent group docker

# 检查Docker服务状态
sudo systemctl status docker

# 测试Docker权限
sudo -u jenkins docker ps
```

### Maven/Node.js问题
```bash
# 检查工具安装
which mvn
which node
which npm

# 检查版本
mvn -version
node --version
npm --version
```

### 网络连接问题
```bash
# 测试GitHub连接
curl -I https://github.com

# 测试Maven仓库连接
curl -I https://repo1.maven.org/maven2/

# 测试npm仓库连接
curl -I https://registry.npmjs.org/
```

## 📞 支持联系

如果遇到配置问题，请检查：
1. Jenkins日志：`/var/log/jenkins/jenkins.log`
2. 构建日志：Jenkins项目页面 → 构建历史 → Console Output
3. 系统日志：`journalctl -u jenkins`

配置完成后，建议运行一次完整的构建流程来验证所有配置是否正确。
