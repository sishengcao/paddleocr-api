# ===================================================================
# Java Spring Boot 应用 Dockerfile 示例
# ===================================================================

# ==================== 构建阶段 ====================
FROM maven:3.9-eclipse-temurin-17 AS build-stage

# 设置工作目录
WORKDIR /app

# 配置 Maven 国内镜像源（阿里云）
RUN mkdir -p /root/.m2 && \
    cat > /root/.m2/settings.xml <<EOF
<settings>
  <mirrors>
    <mirror>
      <id>aliyun-maven</id>
      <name>Aliyun Maven Mirror</name>
      <url>https://maven.aliyun.com/repository/public</url>
      <mirrorOf>central</mirrorOf>
    </mirror>
    <mirror>
      <id>aliyun-spring</id>
      <name>Aliyun Spring Mirror</name>
      <url>https://maven.aliyun.com/repository/spring</url>
      <mirrorOf>spring-releases</mirrorOf>
    </mirror>
  </mirrors>
</settings>
EOF

# 复制 pom.xml（利用 Docker 缓存）
COPY pom.xml .

# 下载依赖（利用 Docker 缓存层）
RUN mvn dependency:go-offline -B

# 复制源代码
COPY src ./src

# 构建应用（跳过测试以加快构建速度）
RUN mvn clean package -DskipTests -B

# ==================== 运行阶段 ====================
FROM eclipse-temurin:17-jre-alpine

# 安装时区数据和 curl（用于健康检查）
RUN apk add --no-cache tzdata curl && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    apk del tzdata

# 设置工作目录
WORKDIR /app

# 从构建阶段复制 JAR 文件
COPY --from=build-stage /app/target/*.jar app.jar

# 创建非 root 用户
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# 暴露端口
EXPOSE 8080

# JVM 参数
ENV JAVA_OPTS="-Xms512m -Xmx1024m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# 启动应用
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
