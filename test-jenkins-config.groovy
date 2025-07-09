// Jenkins配置验证脚本
// 在Jenkins Script Console中运行此脚本来验证配置

pipeline {
    agent any
    
    tools {
        maven 'Maven-3.9.5'
        nodejs 'NodeJS-20'
    }
    
    stages {
        stage('验证工具配置') {
            steps {
                script {
                    echo '=== 验证Java环境 ==='
                    sh 'java -version'
                    
                    echo '=== 验证Maven配置 ==='
                    sh 'mvn -version'
                    
                    echo '=== 验证Node.js配置 ==='
                    sh 'node --version'
                    sh 'npm --version'
                    
                    echo '=== 验证Docker权限 ==='
                    try {
                        sh 'docker --version'
                        sh 'docker ps'
                        echo '✅ Docker权限配置正确'
                    } catch (Exception e) {
                        echo "❌ Docker权限配置有问题: ${e.getMessage()}"
                        echo '请检查Jenkins用户是否在docker组中'
                    }
                    
                    echo '=== 验证环境变量 ==='
                    sh 'echo "JAVA_HOME: $JAVA_HOME"'
                    sh 'echo "MAVEN_HOME: $MAVEN_HOME"'
                    sh 'echo "PATH: $PATH"'
                }
            }
        }
        
        stage('测试基本构建') {
            steps {
                script {
                    echo '=== 测试Maven项目结构 ==='
                    if (fileExists('pom.xml')) {
                        sh 'mvn clean compile -q'
                        echo '✅ Maven编译测试通过'
                    } else {
                        echo '⚠️ 未找到pom.xml文件'
                    }
                    
                    echo '=== 测试前端项目结构 ==='
                    if (fileExists('frontend/regulation-web/package.json')) {
                        dir('frontend/regulation-web') {
                            sh 'npm --version'
                            echo '✅ 前端项目结构正确'
                        }
                    } else {
                        echo '⚠️ 未找到前端项目'
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo '=== 配置验证完成 ==='
        }
        success {
            echo '🎉 所有配置验证通过！'
        }
        failure {
            echo '❌ 配置验证失败，请检查相关配置'
        }
    }
}
