pipeline {
    agent any

    // 工具版本配置
    tools {
        maven 'Maven-3.9.5'
        nodejs 'NodeJS-20'
    }

    // 环境变量
    environment {
        // Docker配置
        DOCKER_REGISTRY = 'docker-registry.ljs.life'
        IMAGE_TAG = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}"
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'

        // 项目配置
        PROJECT_NAME = 'bank-policy-comparison-platform'
        BACKEND_IMAGE = 'regulation-backend'
        FRONTEND_WEB_IMAGE = 'regulation-web'
        FRONTEND_ADMIN_IMAGE = 'regulation-admin'

        // Maven配置 (Java 17兼容)
        MAVEN_OPTS = '-Dmaven.repo.local=.m2/repository -Xmx2048m -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=512m'

        // Node.js配置
        NODE_OPTIONS = '--max-old-space-size=4096'

        // 通知配置
        DEFAULT_EMAIL = 'admin@example.com'
        NOTIFICATION_EMAIL = "${env.CHANGE_AUTHOR_EMAIL ?: (env.GIT_AUTHOR_EMAIL ?: env.DEFAULT_EMAIL)}"
    }

    // 构建选项
    options {
        // 保留最近10次构建
        buildDiscarder(logRotator(numToKeepStr: '10'))
        // 构建超时30分钟
        timeout(time: 30, unit: 'MINUTES')
        // 禁用并发构建
        disableConcurrentBuilds()
        // 添加时间戳到控制台输出
        timestamps()
    }

    // 流水线阶段
    stages {
        // 阶段1: 环境准备
        stage('环境准备') {
            steps {
                echo '=== 环境准备阶段 ==='
                script {
                    // 显示构建信息
                    echo "构建分支: ${env.BRANCH_NAME}"
                    echo "构建编号: ${env.BUILD_NUMBER}"
                    echo "镜像标签: ${env.IMAGE_TAG}"
                    echo "Git提交: ${env.GIT_COMMIT}"
                }

                // 检出代码
                echo '正在检出代码...'
                checkout scm

                // 加载环境变量
                script {
                    if (fileExists('.env')) {
                        echo '加载.env环境变量文件...'
                        def envVars = readFile('.env').split('\n')
                        envVars.each { line ->
                            if (line && !line.startsWith('#') && line.contains('=')) {
                                def parts = line.split('=', 2)
                                if (parts.length == 2) {
                                    env."${parts[0].trim()}" = parts[1].trim()
                                }
                            }
                        }
                    }
                }

                echo '环境准备完成'
            }
        }

        // 阶段2: 代码质量检查
        stage('代码质量检查') {
            parallel {
                stage('后端代码检查') {
                    steps {
                        echo '=== 后端代码质量检查 ==='
                        script {
                            try {
                                sh 'mvn clean compile -q'
                                echo '后端编译成功'

                                // 如果项目配置了checkstyle，则执行检查
                                if (fileExists('checkstyle.xml') || sh(script: 'mvn help:describe -Dplugin=checkstyle -q', returnStatus: true) == 0) {
                                    sh 'mvn checkstyle:check -q'
                                    echo 'Checkstyle检查通过'
                                } else {
                                    echo 'Checkstyle未配置，跳过代码风格检查'
                                }
                            } catch (Exception e) {
                                error "后端代码检查失败: ${e.getMessage()}"
                            }
                        }
                    }
                }
                stage('前端代码检查') {
                    steps {
                        echo '=== 前端代码质量检查 ==='
                        script {
                            // 检查用户端前端
                            dir('frontend/regulation-web') {
                                try {
                                    sh 'npm ci --silent'
                                    sh 'npm run lint'
                                    echo '用户端前端代码检查通过'
                                } catch (Exception e) {
                                    error "用户端前端代码检查失败: ${e.getMessage()}"
                                }
                            }

                            // 检查管理端前端
                            dir('frontend/regulation-admin') {
                                try {
                                    sh 'npm ci --silent'
                                    sh 'npm run lint'
                                    echo '管理端前端代码检查通过'
                                } catch (Exception e) {
                                    error "管理端前端代码检查失败: ${e.getMessage()}"
                                }
                            }
                        }
                    }
                }
            }
        }

        // 阶段3: 编译检查
        stage('编译检查') {
            steps {
                echo '=== 编译检查阶段 ==='
                script {
                    try {
                        sh 'mvn clean compile -q'
                        echo '后端编译成功'
                    } catch (Exception e) {
                        error "后端编译失败: ${e.getMessage()}"
                    }
                }
            }
        }

        // 阶段4: 后端单元测试
        stage('后端单元测试') {
            steps {
                echo '=== 后端单元测试 ==='
                script {
                    try {
                        sh 'mvn test -q'
                        echo '后端单元测试通过'
                    } catch (Exception e) {
                        error "后端单元测试失败: ${e.getMessage()}"
                    }
                }
            }
            post {
                always {
                    // 发布测试报告
                    script {
                        try {
                            // 检查是否存在测试报告文件
                            def testReportFiles = sh(
                                script: 'find . -path "*/target/surefire-reports/*.xml" -type f 2>/dev/null | wc -l',
                                returnStdout: true
                            ).trim().toInteger()

                            if (testReportFiles > 0) {
                                echo "发现 ${testReportFiles} 个测试报告文件"
                                junit(
                                    testResults: '**/target/surefire-reports/*.xml',
                                    allowEmptyResults: true
                                )
                                echo '测试报告发布成功'
                            } else {
                                echo '未发现测试报告文件，可能项目中没有测试用例'
                                echo '提示：请在各模块的 src/test/java 目录下添加测试文件'
                            }
                        } catch (Exception e) {
                            echo "测试报告处理失败: ${e.getMessage()}"
                        }
                    }
                }
            }
        }

        // 阶段5: 前端单元测试
        stage('前端单元测试') {
            steps {
                echo '=== 前端单元测试 ==='
                script {
                    // 测试用户端前端
                    dir('frontend/regulation-web') {
                        try {
                            echo '开始用户端前端测试...'
                            sh 'npm ci --silent'
                            // 检查package.json中是否有test:unit脚本
                            def packageJson = readJSON file: 'package.json'
                            if (packageJson.scripts && packageJson.scripts['test:unit']) {
                                sh 'npm run test:unit'  // 标准化为CI模式
                                echo '用户端前端测试通过'
                            } else {
                                echo '用户端前端未配置test:unit脚本，跳过测试'
                            }
                        } catch (Exception e) {
                            echo "用户端前端测试失败: ${e.getMessage()}"
                            currentBuild.result = 'UNSTABLE'
                        }
                    }

                    // 测试管理端前端
                    dir('frontend/regulation-admin') {
                        try {
                            echo '开始管理端前端测试...'
                            sh 'npm ci --silent'
                            // 检查package.json中是否有test:unit脚本
                            def packageJson = readJSON file: 'package.json'
                            if (packageJson.scripts && packageJson.scripts['test:unit']) {
                                sh 'npm run test:unit'  // 标准化为CI模式
                                echo '管理端前端测试通过'
                            } else {
                                echo '管理端前端未配置test:unit脚本，跳过测试'
                            }
                        } catch (Exception e) {
                            echo "管理端前端测试失败: ${e.getMessage()}"
                            currentBuild.result = 'UNSTABLE'
                        }
                    }
                }
            }
        }

        // 阶段6: 构建应用
        stage('构建应用') {
            parallel {
                stage('后端构建') {
                    steps {
                        echo '=== 后端应用构建 ==='
                        script {
                            try {
                                // 构建整个项目
                                sh 'mvn clean package -DskipTests -q'

                                // 验证构建结果（假设gateway是主要模块，调整为实际主JAR）
                                def jarFile = sh(
                                    script: 'find gateway/target -name "*.jar" -not -name "*sources.jar" -not -name "*javadoc.jar" | head -1',
                                    returnStdout: true
                                ).trim()

                                if (jarFile) {
                                    echo "后端构建成功，JAR文件: ${jarFile}"
                                    env.BACKEND_JAR_FILE = jarFile
                                } else {
                                    error '后端构建失败：未找到JAR文件'
                                }
                            } catch (Exception e) {
                                error "后端构建失败: ${e.getMessage()}"
                            }
                        }
                    }
                }
                stage('前端构建') {
                    steps {
                        echo '=== 前端应用构建 ==='
                        script {
                            // 构建用户端前端
                            dir('frontend/regulation-web') {
                                try {
                                    sh 'npm ci --silent'
                                    sh 'npm run build'
                                    echo '用户端前端构建成功'
                                } catch (Exception e) {
                                    error "用户端前端构建失败: ${e.getMessage()}"
                                }
                            }

                            // 构建管理端前端
                            dir('frontend/regulation-admin') {
                                try {
                                    sh 'npm ci --silent'
                                    sh 'npm run build'
                                    echo '管理端前端构建成功'
                                } catch (Exception e) {
                                    error "管理端前端构建失败: ${e.getMessage()}"
                                }
                            }
                        }
                    }
                }
            }
        }

        // 阶段7: Docker镜像构建
        stage('Docker镜像构建') {
            steps {
                echo '=== Docker镜像构建 ==='
                script {
                    try {
                        // 验证Docker可用性
                        sh 'docker --version'
                        echo '✅ Docker客户端可用'

                        // 构建后端镜像（开发环境，指定Dockerfile）
                        echo '构建后端Docker镜像...'
                        def backendImage = docker.build(
                            "${BACKEND_IMAGE}:${IMAGE_TAG}",
                            "-f Dockerfile --target development ."
                        )
                        env.BACKEND_IMAGE_FULL = "${BACKEND_IMAGE}:${IMAGE_TAG}"
                        echo "后端镜像构建成功: ${env.BACKEND_IMAGE_FULL}"

                        // 构建用户端前端镜像
                        echo '构建用户端前端Docker镜像...'
                        def webImage = docker.build(
                            "${FRONTEND_WEB_IMAGE}:${IMAGE_TAG}",
                            "-f frontend/regulation-web/Dockerfile ./frontend/regulation-web"
                        )
                        env.FRONTEND_WEB_IMAGE_FULL = "${FRONTEND_WEB_IMAGE}:${IMAGE_TAG}"
                        echo "用户端前端镜像构建成功: ${env.FRONTEND_WEB_IMAGE_FULL}"

                        // 构建管理端前端镜像
                        echo '构建管理端前端Docker镜像...'
                        def adminImage = docker.build(
                            "${FRONTEND_ADMIN_IMAGE}:${IMAGE_TAG}",
                            "-f frontend/regulation-admin/Dockerfile ./frontend/regulation-admin"
                        )
                        env.FRONTEND_ADMIN_IMAGE_FULL = "${FRONTEND_ADMIN_IMAGE}:${IMAGE_TAG}"
                        echo "管理端前端镜像构建成功: ${env.FRONTEND_ADMIN_IMAGE_FULL}"

                        echo 'Docker镜像构建完成'
                    } catch (Exception e) {
                        error "Docker镜像构建失败: ${e.getMessage()}"
                    }
                }
            }
        }

        // 阶段8: Docker镜像推送
        stage('Docker镜像推送') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                    branch 'develop'
                }
            }
            steps {
                echo '=== Docker镜像推送 ==='
                script {
                    try {
                        docker.withRegistry("https://${env.DOCKER_REGISTRY}", 'registry-credentials-id') {  // 假设Jenkins有此凭证ID
                            docker.image(env.BACKEND_IMAGE_FULL).push()
                            docker.image(env.FRONTEND_WEB_IMAGE_FULL).push()
                            docker.image(env.FRONTEND_ADMIN_IMAGE_FULL).push()
                            echo '镜像推送成功'
                        }
                    } catch (Exception e) {
                        error "镜像推送失败: ${e.getMessage()}"
                    }
                }
            }
        }

        // 阶段9: 服务健康检查
        stage('服务健康检查') {
            steps {
                echo '=== 服务健康检查 ==='
                script {
                    try {
                        // 验证Docker Compose可用性
                        def composeResult = sh(script: 'docker-compose --version || docker compose version', returnStatus: true)
                        if (composeResult != 0) {
                            echo '⚠️ Docker Compose不可用，跳过服务健康检查'
                            currentBuild.result = 'UNSTABLE'
                            return
                        }
                        echo '✅ Docker Compose可用'

                        // 启动基础服务进行健康检查
                        echo '启动基础服务...'
                        sh 'docker-compose up -d postgres redis elasticsearch rabbitmq'

                        // 等待服务启动（增加等待时间）
                        echo '等待服务启动...'
                        sleep(time: 120, unit: 'SECONDS')

                        // 检查服务健康状态（使用更精确的方法）
                        echo '检查服务健康状态...'
                        def services = ['postgres', 'redis', 'elasticsearch', 'rabbitmq']
                        services.each { service ->
                            def healthStatus = sh(
                                script: "docker inspect --format '{{.State.Health.Status}}' \$(docker-compose ps -q ${service}) || echo 'unhealthy'",
                                returnStdout: true
                            ).trim()

                            if (healthStatus == 'healthy' || healthStatus == 'running') {
                                echo "${service} 服务健康"
                            } else {
                                echo "警告: ${service} 服务可能未正常启动: ${healthStatus}"
                                currentBuild.result = 'UNSTABLE'
                            }
                        }

                        echo '基础服务健康检查完成'
                    } catch (Exception e) {
                        echo "服务健康检查失败: ${e.getMessage()}"
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
            post {
                always {
                    script {
                        try {
                            echo '清理测试服务...'
                            sh 'docker-compose down || true'
                        } catch (Exception e) {
                            echo "清理服务失败: ${e.getMessage()}"
                        }
                    }
                }
            }
        }

        // 阶段10: 部署
        stage('部署') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                    branch 'develop'
                }
            }
            steps {
                echo '=== 部署阶段 ==='
                script {
                    try {
                        // 验证Docker Compose可用性
                        def composeResult = sh(script: 'docker-compose --version || docker compose version', returnStatus: true)
                        if (composeResult != 0) {
                            echo '⚠️ Docker Compose不可用，跳过部署'
                            currentBuild.result = 'UNSTABLE'
                            return
                        }
                        echo '✅ Docker Compose可用'

                        def deployEnv = env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master' ? 'production' : 'development'
                        echo "部署到${deployEnv}环境..."

                        // 注入环境变量到部署
                        withEnv(["BACKEND_IMAGE=${env.BACKEND_IMAGE_FULL}",
                                 "FRONTEND_WEB_IMAGE=${env.FRONTEND_WEB_IMAGE_FULL}",
                                 "FRONTEND_ADMIN_IMAGE=${env.FRONTEND_ADMIN_IMAGE_FULL}",
                                 "IMAGE_TAG=${env.IMAGE_TAG}"]) {

                            // 停止现有服务
                            echo '停止现有服务...'
                            sh 'docker-compose down || true'

                            // 清理旧镜像（可选）
                            if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master') {
                                echo '清理旧镜像...'
                                sh 'docker image prune -f || true'
                            }

                            // 启动服务
                            echo '启动服务...'
                            if (deployEnv == 'production') {
                                sh 'docker-compose --profile production up -d'
                            } else {
                                sh 'docker-compose up -d'
                            }
                        }

                        // 等待服务启动
                        echo '等待服务启动...'
                        sleep(time: 60, unit: 'SECONDS')

                        // 验证部署（假设本地可用；如远程，可改为远程curl或健康检查工具）
                        echo '验证部署状态...'
                        def backendHealth = sh(
                            script: 'curl -f -s http://localhost:8080/actuator/health | grep UP || echo "unhealthy"',
                            returnStdout: true
                        ).trim()

                        if (backendHealth.contains('UP')) {
                            echo '后端服务部署成功'
                        } else {
                            echo '警告: 后端服务可能未正常启动'
                            currentBuild.result = 'UNSTABLE'
                        }

                        echo "部署到${deployEnv}环境完成"
                    } catch (Exception e) {
                        error "部署失败: ${e.getMessage()}"
                    }
                }
            }
        }
    }

    // 构建后操作
    post {
        always {
            echo '=== 构建后清理 ==='
            script {
                try {
                    // 发布构建产物
                    if (env.BACKEND_JAR_FILE) {
                        archiveArtifacts artifacts: "${env.BACKEND_JAR_FILE}", fingerprint: true, allowEmptyArchive: true
                    }

                    // 保存构建日志
                    echo '保存构建信息...'
                    writeFile file: 'build-info.txt', text: """
构建信息:
- 项目: ${env.PROJECT_NAME}
- 分支: ${env.BRANCH_NAME}
- 构建号: ${env.BUILD_NUMBER}
- Git提交: ${env.GIT_COMMIT}
- 镜像标签: ${env.IMAGE_TAG}
- 构建时间: ${new Date()}
- 构建状态: ${currentBuild.result ?: 'SUCCESS'}
"""
                    archiveArtifacts artifacts: 'build-info.txt', fingerprint: true, allowEmptyArchive: true

                } catch (Exception e) {
                    echo "清理过程中出现错误: ${e.getMessage()}"
                }
            }

            // 清理工作空间（排除重要目录）
            cleanWs(
                cleanWhenNotBuilt: false,
                deleteDirs: true,
                disableDeferredWipeout: true,
                notFailBuild: true,
                patterns: [
                    [pattern: '.git', type: 'EXCLUDE'],
                    [pattern: '.m2', type: 'EXCLUDE'],
                    [pattern: 'node_modules', type: 'EXCLUDE'],
                    [pattern: '**/target', type: 'EXCLUDE'],  // 保留构建产物
                    [pattern: '**/dist', type: 'EXCLUDE']    // 保留前端构建输出
                ]
            )
        }

        success {
            echo '🎉 构建成功！'
            script {
                try {
                    // 发送成功通知
                    emailext (
                        subject: "✅ 构建成功: ${env.PROJECT_NAME} - ${env.BRANCH_NAME} #${env.BUILD_NUMBER}",
                        body: """
<h2>构建成功通知</h2>
<p><strong>项目:</strong> ${env.PROJECT_NAME}</p>
<p><strong>分支:</strong> ${env.BRANCH_NAME}</p>
<p><strong>构建号:</strong> ${env.BUILD_NUMBER}</p>
<p><strong>Git提交:</strong> ${env.GIT_COMMIT}</p>
<p><strong>镜像标签:</strong> ${env.IMAGE_TAG}</p>
<p><strong>构建时间:</strong> ${new Date()}</p>
<p><strong>详情:</strong> <a href="${env.BUILD_URL}">查看构建详情</a></p>
""",
                        mimeType: 'text/html',
                        to: "${env.NOTIFICATION_EMAIL}"
                    )
                } catch (Exception e) {
                    echo "发送成功通知失败: ${e.getMessage()}"
                }
            }
        }

        failure {
            echo '❌ 构建失败！'
            script {
                try {
                    // 发送失败通知
                    emailext (
                        subject: "❌ 构建失败: ${env.PROJECT_NAME} - ${env.BRANCH_NAME} #${env.BUILD_NUMBER}",
                        body: """
<h2>构建失败通知</h2>
<p><strong>项目:</strong> ${env.PROJECT_NAME}</p>
<p><strong>分支:</strong> ${env.BRANCH_NAME}</p>
<p><strong>构建号:</strong> ${env.BUILD_NUMBER}</p>
<p><strong>Git提交:</strong> ${env.GIT_COMMIT}</p>
<p><strong>失败时间:</strong> ${new Date()}</p>
<p><strong>详情:</strong> <a href="${env.BUILD_URL}">查看构建详情</a></p>
<p><strong>控制台日志:</strong> <a href="${env.BUILD_URL}console">查看控制台输出</a></p>
""",
                        mimeType: 'text/html',
                        to: "${env.NOTIFICATION_EMAIL}"
                    )
                } catch (Exception e) {
                    echo "发送失败通知失败: ${e.getMessage()}"
                }
            }
        }

        unstable {
            echo '⚠️ 构建不稳定'
            script {
                try {
                    emailext (
                        subject: "⚠️ 构建不稳定: ${env.PROJECT_NAME} - ${env.BRANCH_NAME} #${env.BUILD_NUMBER}",
                        body: """
<h2>构建不稳定通知</h2>
<p>构建完成但存在警告或非关键性错误。</p>
<p><strong>项目:</strong> ${env.PROJECT_NAME}</p>
<p><strong>分支:</strong> ${env.BRANCH_NAME}</p>
<p><strong>构建号:</strong> ${env.BUILD_NUMBER}</p>
<p><strong>详情:</strong> <a href="${env.BUILD_URL}">查看构建详情</a></p>
""",
                        mimeType: 'text/html',
                        to: "${env.NOTIFICATION_EMAIL}"
                    )
                } catch (Exception e) {
                    echo "发送不稳定通知失败: ${e.getMessage()}"
                }
            }
        }
    }
}
