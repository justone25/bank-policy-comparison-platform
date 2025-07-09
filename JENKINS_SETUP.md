# Jenkins CI/CD 配置指南

## 概述

本文档说明了为银行政策比较平台（监管合规智能系统）配置的Jenkins CI/CD流水线。

## 项目结构

```
bank-policy-comparison-platform/
├── common/                 # 公共模块
├── core/                   # 核心模块  
├── nlp/                    # 自然语言处理模块
├── search/                 # 搜索模块
├── gateway/                # 网关模块（主要可执行模块）
├── frontend/
│   ├── regulation-web/     # 用户端前端（Vue.js）
│   └── regulation-admin/   # 管理端前端（Vue.js）
├── docker/                 # Docker配置文件
├── Dockerfile              # 后端多阶段构建
├── docker-compose.yml      # 服务编排
├── Jenkinsfile            # CI/CD流水线配置
└── .env                   # 环境变量配置
```

## Jenkinsfile 主要修改

### 1. 环境变量优化
- 添加了项目特定的环境变量
- 支持.env文件自动加载
- 优化了Maven和Node.js内存配置

### 2. 构建流程改进
- **环境准备**: 自动加载.env文件，显示构建信息
- **代码质量检查**: 并行检查后端和两个前端项目
- **单元测试**: 修正了前端测试命令（`npm run test:unit`）
- **应用构建**: 优化Maven多模块构建，专门构建gateway模块
- **Docker镜像构建**: 支持多阶段构建，分别构建后端和前端镜像
- **服务健康检查**: 替换了不存在的集成测试，改为基础服务健康检查
- **部署**: 支持多分支部署策略

### 3. 错误处理增强
- 添加了详细的错误处理和日志记录
- 前端测试失败不会阻断构建，但会标记为不稳定
- 改进了清理逻辑

### 4. 通知系统
- 增强的邮件通知，包含HTML格式
- 支持成功、失败、不稳定三种状态通知
- 自动归档构建产物和构建信息

## Jenkins 环境要求

### 必需的工具
- **Maven 3.9.5**: 配置名称为 `Maven-3.9.5`
- **Node.js 20**: 配置名称为 `NodeJS-20`
- **Docker**: Jenkins agent需要有Docker权限

### 必需的插件
- Pipeline Plugin
- Docker Pipeline Plugin
- Email Extension Plugin
- Build Timeout Plugin
- Timestamper Plugin

## GitHub 集成配置

### 1. Webhook 配置
在GitHub仓库设置中添加Jenkins webhook：
```
URL: http://your-jenkins-server/github-webhook/
Content type: application/json
Events: Push events, Pull request events
```

### 2. Jenkins 项目配置
1. 创建新的Pipeline项目
2. 在"Pipeline"部分选择"Pipeline script from SCM"
3. SCM选择"Git"，填入仓库URL
4. 分支指定为`*/main`或`*/*`（支持所有分支）
5. Script Path设置为`Jenkinsfile`

### 3. 分支策略
- **main/master分支**: 部署到生产环境
- **develop分支**: 部署到开发环境  
- **其他分支**: 只进行构建和测试，不部署

## 环境变量配置

### Jenkins 全局环境变量
建议在Jenkins中配置以下环境变量：
```bash
DOCKER_REGISTRY=your-docker-registry.com
NOTIFICATION_EMAIL=admin@yourcompany.com
```

### 项目.env文件
项目根目录的.env文件会被自动加载，包含：
- 数据库配置
- Redis配置  
- Elasticsearch配置
- RabbitMQ配置
- 端口配置

## 构建流程说明

### 阶段1: 环境准备
- 检出代码
- 加载.env环境变量
- 显示构建信息

### 阶段2: 代码质量检查
- 后端: Maven编译 + Checkstyle检查
- 前端: ESLint代码检查（两个前端项目）

### 阶段3: 单元测试
- 后端: Maven单元测试
- 前端: Vitest单元测试

### 阶段4: 应用构建
- 后端: Maven打包（gateway模块）
- 前端: Vite构建

### 阶段5: Docker镜像构建
- 后端: 多阶段构建（development target）
- 前端: 分别构建两个前端镜像

### 阶段6: 服务健康检查
- 启动基础服务（PostgreSQL, Redis, Elasticsearch, RabbitMQ）
- 检查服务健康状态

### 阶段7: 部署
- 仅在main/master/develop分支执行
- 使用docker-compose部署
- 验证部署状态

## 故障排除

### 常见问题

1. **Maven构建失败**
   - 检查Java版本是否为17
   - 确认Maven配置正确
   - 查看依赖是否能正常下载

2. **前端构建失败**
   - 检查Node.js版本是否为20
   - 确认npm依赖安装成功
   - 查看内存配置是否足够

3. **Docker构建失败**
   - 确认Jenkins agent有Docker权限
   - 检查Dockerfile语法
   - 查看Docker daemon是否运行

4. **部署失败**
   - 检查端口是否被占用
   - 确认.env文件配置正确
   - 查看服务依赖是否正常

### 日志查看
- Jenkins控制台输出: `${BUILD_URL}console`
- 构建详情: `${BUILD_URL}`
- 归档的构建信息: 下载`build-info.txt`

## 安全建议

1. **生产环境密码**: 修改.env文件中的默认密码
2. **Jenkins凭据**: 使用Jenkins凭据管理敏感信息
3. **网络安全**: 配置防火墙规则限制访问
4. **定期更新**: 保持Jenkins和插件版本更新

## 性能优化

1. **构建缓存**: 配置Maven和npm缓存
2. **并行构建**: 利用多核CPU并行执行
3. **Docker缓存**: 优化Docker镜像层缓存
4. **资源限制**: 合理配置内存和CPU限制
