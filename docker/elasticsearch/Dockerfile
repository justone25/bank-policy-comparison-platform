FROM docker.elastic.co/elasticsearch/elasticsearch:7.17.9

USER root
RUN if [ -f /etc/redhat-release ]; then \
        yum update -y && yum install -y wget curl && yum clean all; \
    elif [ -f /etc/debian_version ]; then \
        apt-get update && apt-get install -y wget curl && \
        rm -rf /var/lib/apt/lists/*; \
    fi

USER elasticsearch

# 清理可能存在的插件残留
RUN rm -rf /usr/share/elasticsearch/plugins/analysis-ik || true

# 安装IK插件
RUN elasticsearch-plugin install --batch \
    https://release.infinilabs.com/analysis-ik/stable/elasticsearch-analysis-ik-7.17.9.zip

# 验证插件安装 - 使用正确的目录名
RUN elasticsearch-plugin list && \
    ls -la /usr/share/elasticsearch/plugins/analysis-ik/ && \
    test -f /usr/share/elasticsearch/plugins/analysis-ik/plugin-descriptor.properties

# 创建配置目录 - 使用正确的路径
USER root
RUN mkdir -p /usr/share/elasticsearch/plugins/analysis-ik/config && \
    chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/plugins/analysis-ik/

USER elasticsearch

COPY --chown=elasticsearch:elasticsearch docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 9200 9300

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9200/_cluster/health || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]