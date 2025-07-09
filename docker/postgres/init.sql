-- =============================================================================
-- 监管合规智能系统数据库初始化脚本
-- Regulation Compliance System Database Initialization
-- =============================================================================

-- 设置客户端编码
SET client_encoding = 'UTF8';

-- 连接到默认数据库创建用户和数据库
\c postgres;

-- =============================================================================
-- 1. 创建数据库和用户
-- =============================================================================

-- 创建应用数据库用户
DO $$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'regulation_user') THEN
            CREATE USER regulation_user WITH ENCRYPTED PASSWORD 'regulation_password123';
        END IF;
    END
$$;

-- 创建测试数据库用户
DO $$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'regulation_test_user') THEN
            CREATE USER regulation_test_user WITH ENCRYPTED PASSWORD 'test_password123';
        END IF;
    END
$$;

-- 创建只读用户（用于报告和查询）
DO $$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'regulation_readonly') THEN
            CREATE USER regulation_readonly WITH ENCRYPTED PASSWORD 'readonly_password123';
        END IF;
    END
$$;

-- 创建业务数据库
-- 注意：CREATE DATABASE 不能在 DO 块中执行，需要直接执行
-- 使用 psql 的条件执行来避免重复创建错误
SELECT 'CREATE DATABASE regulation_db WITH OWNER = regulation_user ENCODING = ''UTF8'' LC_COLLATE = ''C'' LC_CTYPE = ''C'' TEMPLATE = template0;'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'regulation_db')\gexec

-- 创建测试数据库
SELECT 'CREATE DATABASE regulation_test_db WITH OWNER = regulation_test_user ENCODING = ''UTF8'' LC_COLLATE = ''C'' LC_CTYPE = ''C'' TEMPLATE = template0;'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'regulation_test_db')\gexec

-- 为应用用户授权
GRANT ALL PRIVILEGES ON DATABASE regulation_db TO regulation_user;
GRANT ALL PRIVILEGES ON DATABASE regulation_test_db TO regulation_test_user;

-- 为只读用户授权
GRANT CONNECT ON DATABASE regulation_db TO regulation_readonly;

-- =============================================================================
-- 2. 连接到业务数据库并创建扩展
-- =============================================================================

\c regulation_db;

-- 创建必要的扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";           -- UUID生成
CREATE EXTENSION IF NOT EXISTS "pg_trgm";             -- 模糊匹配和相似性搜索
CREATE EXTENSION IF NOT EXISTS "btree_gin";           -- GIN索引支持更多数据类型
CREATE EXTENSION IF NOT EXISTS "unaccent";            -- 去除重音符号
-- 注意：pg_stat_statements 可能需要预加载，如果失败可以注释掉
-- CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";  -- 查询性能统计

-- 创建中文全文搜索配置（简化版）
-- 注意：这是基础配置，生产环境建议使用专门的中文分词工具
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'chinese_simple') THEN
            CREATE TEXT SEARCH CONFIGURATION chinese_simple (COPY = simple);
        END IF;
    END
$$;

-- =============================================================================
-- 3. 创建枚举类型
-- =============================================================================

-- 监管机构枚举
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'regulatory_body_enum') THEN
            CREATE TYPE regulatory_body_enum AS ENUM (
                'CBIRC',      -- 银保监会
                'PBOC',       -- 人民银行
                'CSRC',       -- 证监会
                'SAFE',       -- 外汇管理局
                'MOF',        -- 财政部
                'NDRC',       -- 发改委
                'OTHER'       -- 其他
                );
        END IF;
    END
$$;

-- 文档类型枚举
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_type_enum') THEN
            CREATE TYPE document_type_enum AS ENUM (
                'LAW',                    -- 法律
                'REGULATION',             -- 行政法规
                'DEPARTMENTAL_RULE',      -- 部门规章
                'NORMATIVE_DOCUMENT',     -- 规范性文件
                'NOTICE',                 -- 通知
                'ANNOUNCEMENT',           -- 公告
                'GUIDELINE',              -- 指导意见
                'STANDARD',               -- 标准
                'OTHER'                   -- 其他
                );
        END IF;
    END
$$;

-- 业务领域枚举
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'business_domain_enum') THEN
            CREATE TYPE business_domain_enum AS ENUM (
                'CAPITAL_MANAGEMENT',     -- 资本管理
                'RISK_MANAGEMENT',        -- 风险管理
                'LIQUIDITY_MANAGEMENT',   -- 流动性管理
                'CREDIT_RISK',            -- 信用风险
                'MARKET_RISK',            -- 市场风险
                'OPERATIONAL_RISK',       -- 操作风险
                'COMPLIANCE',             -- 合规管理
                'INTERNAL_CONTROL',       -- 内部控制
                'INFORMATION_DISCLOSURE', -- 信息披露
                'CONSUMER_PROTECTION',    -- 消费者保护
                'ANTI_MONEY_LAUNDERING',  -- 反洗钱
                'DATA_GOVERNANCE',        -- 数据治理
                'FINTECH',                -- 金融科技
                'GREEN_FINANCE',          -- 绿色金融
                'OTHER'                   -- 其他
                );
        END IF;
    END
$$;

-- 条款类型枚举
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'clause_type_enum') THEN
            CREATE TYPE clause_type_enum AS ENUM (
                'DEFINITION',             -- 定义性条款
                'REQUIREMENT',            -- 要求性条款
                'CALCULATION',            -- 计算性条款
                'PROCEDURE',              -- 程序性条款
                'PENALTY',                -- 处罚性条款
                'EXEMPTION',              -- 豁免性条款
                'TRANSITIONAL',           -- 过渡性条款
                'OTHER'                   -- 其他
                );
        END IF;
    END
$$;

-- 文档状态枚举
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_status_enum') THEN
            CREATE TYPE document_status_enum AS ENUM (
                'DRAFT',                  -- 草案
                'ACTIVE',                 -- 有效
                'AMENDED',                -- 已修订
                'SUPERSEDED',             -- 已被替代
                'REPEALED',               -- 已废止
                'SUSPENDED'               -- 已暂停
                );
        END IF;
    END
$$;

-- =============================================================================
-- 4. 创建主要业务表
-- =============================================================================

-- 4.1 法规文档表
CREATE TABLE IF NOT EXISTS regulation_documents (
                                                    document_id VARCHAR(50) PRIMARY KEY,
                                                    title VARCHAR(1000) NOT NULL,
                                                    content TEXT,
                                                    regulatory_body regulatory_body_enum NOT NULL,
                                                    document_type document_type_enum NOT NULL,
                                                    business_domain business_domain_enum[] DEFAULT '{}', -- 支持多个业务领域
                                                    document_number VARCHAR(100),                        -- 文件编号
                                                    effective_date DATE,
                                                    expiry_date DATE,                                    -- 失效日期
                                                    status document_status_enum DEFAULT 'ACTIVE',
                                                    file_path VARCHAR(500),
                                                    file_size INTEGER,
                                                    file_type VARCHAR(20),                               -- pdf, docx, html等
                                                    original_url TEXT,                                   -- 原始下载链接
                                                    keywords TEXT[],                                     -- 关键词数组
                                                    abstract TEXT,                                       -- 摘要
                                                    version_number VARCHAR(20) DEFAULT '1.0',           -- 版本号
                                                    parent_document_id VARCHAR(50),                     -- 父文档ID（用于版本关联）
                                                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                                    created_by VARCHAR(100) DEFAULT 'system',
                                                    updated_by VARCHAR(100) DEFAULT 'system',

    -- 约束
                                                    CONSTRAINT fk_parent_document
                                                        FOREIGN KEY (parent_document_id)
                                                            REFERENCES regulation_documents(document_id),
                                                    CONSTRAINT chk_effective_date
                                                        CHECK (expiry_date IS NULL OR effective_date <= expiry_date)
);

-- 4.2 法规条款表
CREATE TABLE IF NOT EXISTS regulation_clauses (
                                                  clause_id VARCHAR(50) PRIMARY KEY,
                                                  document_id VARCHAR(50) NOT NULL,
                                                  chapter_id VARCHAR(50),                              -- 章节ID
                                                  section_id VARCHAR(50),                              -- 节ID
                                                  clause_number VARCHAR(100),                          -- 条款编号
                                                  clause_title VARCHAR(1000),
                                                  clause_content TEXT NOT NULL,
                                                  clause_type clause_type_enum DEFAULT 'OTHER',
                                                  parent_clause_id VARCHAR(50),                        -- 父条款ID（支持条款层次）
                                                  order_number INTEGER,                                -- 排序号
                                                  is_key_clause BOOLEAN DEFAULT FALSE,                -- 是否为关键条款
                                                  business_concepts TEXT[],                            -- 业务概念标签
                                                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                                  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- 约束
                                                  CONSTRAINT fk_regulation_clauses_document
                                                      FOREIGN KEY (document_id)
                                                          REFERENCES regulation_documents(document_id) ON DELETE CASCADE,
                                                  CONSTRAINT fk_regulation_clauses_parent
                                                      FOREIGN KEY (parent_clause_id)
                                                          REFERENCES regulation_clauses(clause_id)
);

-- 4.3 数据字段表
CREATE TABLE IF NOT EXISTS data_fields (
                                           field_id VARCHAR(50) PRIMARY KEY,
                                           document_id VARCHAR(50) NOT NULL,
                                           clause_id VARCHAR(50),                               -- 关联条款
                                           field_name VARCHAR(500) NOT NULL,
                                           field_code VARCHAR(100),                             -- 字段代码
                                           field_type VARCHAR(50) NOT NULL,                     -- decimal, integer, text, date, boolean
                                           field_unit VARCHAR(50),                              -- 单位
                                           is_required BOOLEAN DEFAULT FALSE,
                                           calculation_method TEXT,
                                           data_sources TEXT[],                                 -- 数据来源
                                           validation_rules JSONB,                              -- 验证规则（JSON格式）
                                           default_value TEXT,
                                           min_value DECIMAL,
                                           max_value DECIMAL,
                                           format_pattern VARCHAR(200),                         -- 格式模式
                                           description TEXT,
                                           created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                           updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- 约束
                                           CONSTRAINT fk_data_fields_document
                                               FOREIGN KEY (document_id)
                                                   REFERENCES regulation_documents(document_id) ON DELETE CASCADE,
                                           CONSTRAINT fk_data_fields_clause
                                               FOREIGN KEY (clause_id)
                                                   REFERENCES regulation_clauses(clause_id) ON DELETE SET NULL,
                                           CONSTRAINT chk_min_max_value
                                               CHECK (min_value IS NULL OR max_value IS NULL OR min_value <= max_value)
);

-- 4.4 计算公式表
CREATE TABLE IF NOT EXISTS calculation_formulas (
                                                    formula_id VARCHAR(50) PRIMARY KEY,
                                                    document_id VARCHAR(50) NOT NULL,
                                                    clause_id VARCHAR(50),
                                                    target_field VARCHAR(500),                           -- 目标字段
                                                    formula_text TEXT NOT NULL,                          -- 公式文本
                                                    formula_expression TEXT,                             -- 标准化公式表达式
                                                    formula_type VARCHAR(50) DEFAULT 'SIMPLE',           -- SIMPLE, COMPLEX, CONDITIONAL
                                                    components JSONB,                                    -- 公式组成部分（JSON格式）
                                                    conditions TEXT,                                     -- 适用条件
                                                    examples TEXT,                                       -- 计算示例
                                                    description TEXT,
                                                    is_active BOOLEAN DEFAULT TRUE,
                                                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- 约束
                                                    CONSTRAINT fk_calculation_formulas_document
                                                        FOREIGN KEY (document_id)
                                                            REFERENCES regulation_documents(document_id) ON DELETE CASCADE,
                                                    CONSTRAINT fk_calculation_formulas_clause
                                                        FOREIGN KEY (clause_id)
                                                            REFERENCES regulation_clauses(clause_id) ON DELETE SET NULL
);

-- 4.5 合规规则表
CREATE TABLE IF NOT EXISTS compliance_rules (
                                                rule_id VARCHAR(50) PRIMARY KEY,
                                                document_id VARCHAR(50) NOT NULL,
                                                clause_id VARCHAR(50),
                                                rule_name VARCHAR(500) NOT NULL,
                                                rule_type VARCHAR(50) NOT NULL,                      -- THRESHOLD, LOGICAL, TEMPORAL, PROCEDURAL
                                                description TEXT,
                                                rule_expression TEXT,                                -- 规则表达式
                                                threshold_value DECIMAL,
                                                threshold_operator VARCHAR(10),                      -- >=, <=, ==, !=, >, <
                                                applicable_institutions TEXT[],                      -- 适用机构类型
                                                penalty_description TEXT,
                                                penalty_amount_min DECIMAL,
                                                penalty_amount_max DECIMAL,
                                                monitoring_frequency VARCHAR(50),                    -- DAILY, WEEKLY, MONTHLY, QUARTERLY, ANNUALLY
                                                grace_period INTEGER,                                -- 宽限期（天）
                                                exemption_conditions TEXT,                           -- 豁免条件
                                                is_active BOOLEAN DEFAULT TRUE,
                                                severity_level INTEGER DEFAULT 1,                    -- 严重程度 1-5
                                                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- 约束
                                                CONSTRAINT fk_compliance_rules_document
                                                    FOREIGN KEY (document_id)
                                                        REFERENCES regulation_documents(document_id) ON DELETE CASCADE,
                                                CONSTRAINT fk_compliance_rules_clause
                                                    FOREIGN KEY (clause_id)
                                                        REFERENCES regulation_clauses(clause_id) ON DELETE SET NULL,
                                                CONSTRAINT chk_severity_level
                                                    CHECK (severity_level BETWEEN 1 AND 5),
                                                CONSTRAINT chk_penalty_amount
                                                    CHECK (penalty_amount_min IS NULL OR penalty_amount_max IS NULL OR penalty_amount_min <= penalty_amount_max)
);

-- 4.6 业务概念词典表
CREATE TABLE IF NOT EXISTS business_concepts (
                                                 concept_id VARCHAR(50) PRIMARY KEY,
                                                 concept_name VARCHAR(500) NOT NULL UNIQUE,
                                                 definition TEXT,
                                                 synonyms TEXT[],                                     -- 同义词
                                                 category VARCHAR(100),
                                                 related_concepts TEXT[],                             -- 相关概念
                                                 business_domain business_domain_enum,
                                                 regulatory_body regulatory_body_enum,
                                                 usage_frequency INTEGER DEFAULT 0,
                                                 is_standard_term BOOLEAN DEFAULT FALSE,              -- 是否为标准术语
                                                 source_documents TEXT[],                             -- 来源文档
                                                 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                                 updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- 5. 创建系统管理表
-- =============================================================================

-- 5.1 解析任务表
CREATE TABLE IF NOT EXISTS parse_tasks (
                                           task_id VARCHAR(50) PRIMARY KEY,
                                           document_id VARCHAR(50),
                                           file_name VARCHAR(500) NOT NULL,
                                           file_path VARCHAR(500),
                                           file_size INTEGER,
                                           status VARCHAR(20) DEFAULT 'PENDING',                -- PENDING, PROCESSING, COMPLETED, FAILED
                                           progress INTEGER DEFAULT 0,                          -- 进度百分比
                                           error_message TEXT,
                                           parse_result JSONB,                                  -- 解析结果JSON
                                           quality_metrics JSONB,                               -- 质量指标JSON
                                           processing_time INTEGER,                             -- 处理耗时（秒）
                                           retry_count INTEGER DEFAULT 0,
                                           created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                           started_at TIMESTAMP,
                                           completed_at TIMESTAMP,
                                           created_by VARCHAR(100),

    -- 约束
                                           CONSTRAINT fk_parse_tasks_document
                                               FOREIGN KEY (document_id)
                                                   REFERENCES regulation_documents(document_id) ON DELETE SET NULL,
                                           CONSTRAINT chk_progress_range
                                               CHECK (progress BETWEEN 0 AND 100)
);

-- 5.2 查询历史表
CREATE TABLE IF NOT EXISTS query_history (
                                             query_id VARCHAR(50) PRIMARY KEY,
                                             user_id VARCHAR(100),
                                             query_text TEXT NOT NULL,
                                             query_type VARCHAR(50),                              -- FULL_TEXT, FIELD_SEARCH, COMPLEX
                                             query_filters JSONB,                                 -- 查询过滤条件JSON
                                             result_count INTEGER,
                                             query_time INTEGER,                                  -- 查询耗时（毫秒）
                                             query_success BOOLEAN DEFAULT TRUE,
                                             error_message TEXT,
                                             ip_address INET,
                                             user_agent TEXT,
                                             created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5.3 用户管理表（基础版本）
CREATE TABLE IF NOT EXISTS users (
                                     user_id VARCHAR(50) PRIMARY KEY,
                                     username VARCHAR(100) NOT NULL UNIQUE,
                                     email VARCHAR(200) NOT NULL UNIQUE,
                                     password_hash VARCHAR(255) NOT NULL,
                                     full_name VARCHAR(200),
                                     department VARCHAR(200),
                                     role VARCHAR(50) DEFAULT 'USER',                     -- ADMIN, USER, READONLY
                                     is_active BOOLEAN DEFAULT TRUE,
                                     last_login_at TIMESTAMP,
                                     failed_login_attempts INTEGER DEFAULT 0,
                                     locked_until TIMESTAMP,
                                     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                     updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5.4 系统配置表
CREATE TABLE IF NOT EXISTS system_config (
                                             config_key VARCHAR(100) PRIMARY KEY,
                                             config_value TEXT,
                                             config_type VARCHAR(50) DEFAULT 'STRING',            -- STRING, INTEGER, BOOLEAN, JSON
                                             description TEXT,
                                             is_public BOOLEAN DEFAULT FALSE,                     -- 是否为公开配置
                                             created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                             updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- 6. 创建索引
-- =============================================================================

-- 主表性能索引
CREATE INDEX IF NOT EXISTS idx_regulation_documents_regulatory_body
    ON regulation_documents(regulatory_body);
CREATE INDEX IF NOT EXISTS idx_regulation_documents_business_domain
    ON regulation_documents USING GIN(business_domain);
CREATE INDEX IF NOT EXISTS idx_regulation_documents_effective_date
    ON regulation_documents(effective_date);
CREATE INDEX IF NOT EXISTS idx_regulation_documents_status
    ON regulation_documents(status);
CREATE INDEX IF NOT EXISTS idx_regulation_documents_keywords
    ON regulation_documents USING GIN(keywords);

-- 条款表索引
CREATE INDEX IF NOT EXISTS idx_regulation_clauses_document_id
    ON regulation_clauses(document_id);
CREATE INDEX IF NOT EXISTS idx_regulation_clauses_clause_type
    ON regulation_clauses(clause_type);
CREATE INDEX IF NOT EXISTS idx_regulation_clauses_business_concepts
    ON regulation_clauses USING GIN(business_concepts);

-- 数据字段表索引
CREATE INDEX IF NOT EXISTS idx_data_fields_document_id
    ON data_fields(document_id);
CREATE INDEX IF NOT EXISTS idx_data_fields_field_type
    ON data_fields(field_type);

-- 合规规则表索引
CREATE INDEX IF NOT EXISTS idx_compliance_rules_document_id
    ON compliance_rules(document_id);
CREATE INDEX IF NOT EXISTS idx_compliance_rules_rule_type
    ON compliance_rules(rule_type);
CREATE INDEX IF NOT EXISTS idx_compliance_rules_is_active
    ON compliance_rules(is_active);

-- 业务概念索引
CREATE INDEX IF NOT EXISTS idx_business_concepts_name
    ON business_concepts(concept_name);
CREATE INDEX IF NOT EXISTS idx_business_concepts_category
    ON business_concepts(category);
CREATE INDEX IF NOT EXISTS idx_business_concepts_synonyms
    ON business_concepts USING GIN(synonyms);

-- 系统表索引
CREATE INDEX IF NOT EXISTS idx_parse_tasks_status
    ON parse_tasks(status);
CREATE INDEX IF NOT EXISTS idx_parse_tasks_created_at
    ON parse_tasks(created_at);
CREATE INDEX IF NOT EXISTS idx_query_history_user_id
    ON query_history(user_id);
CREATE INDEX IF NOT EXISTS idx_query_history_created_at
    ON query_history(created_at);

-- 全文搜索索引
CREATE INDEX IF NOT EXISTS idx_regulation_documents_title_fts
    ON regulation_documents USING gin(to_tsvector('chinese_simple', title));
CREATE INDEX IF NOT EXISTS idx_regulation_documents_content_fts
    ON regulation_documents USING gin(to_tsvector('chinese_simple', content));
CREATE INDEX IF NOT EXISTS idx_regulation_clauses_content_fts
    ON regulation_clauses USING gin(to_tsvector('chinese_simple', clause_content));

-- 复合索引
CREATE INDEX IF NOT EXISTS idx_regulation_documents_body_domain_status
    ON regulation_documents(regulatory_body, status)
    WHERE status = 'ACTIVE';

-- =============================================================================
-- 7. 插入基础数据
-- =============================================================================

-- 7.1 插入系统配置
INSERT INTO system_config (config_key, config_value, config_type, description, is_public) VALUES
                                                                                              ('system.name', '监管合规智能系统', 'STRING', '系统名称', true),
                                                                                              ('system.version', '1.0.0', 'STRING', '系统版本', true),
                                                                                              ('nlp.max_document_size', '52428800', 'INTEGER', 'NLP处理最大文档大小（字节）', false),
                                                                                              ('search.max_results', '1000', 'INTEGER', '搜索结果最大返回数量', false),
                                                                                              ('parse.timeout', '300', 'INTEGER', '文档解析超时时间（秒）', false),
                                                                                              ('cache.ttl', '3600', 'INTEGER', '缓存过期时间（秒）', false)
ON CONFLICT (config_key) DO NOTHING;

-- 7.2 插入基础业务概念
INSERT INTO business_concepts (concept_id, concept_name, definition, category, business_domain, is_standard_term) VALUES
                                                                                                                      ('bc001', '资本充足率', '银行资本与风险加权资产的比率，用于衡量银行抵御风险的能力', '风险管理', 'CAPITAL_MANAGEMENT'::business_domain_enum, true),
                                                                                                                      ('bc002', '核心一级资本', '银行最高质量的资本，主要包括普通股和留存收益', '资本管理', 'CAPITAL_MANAGEMENT'::business_domain_enum, true),
                                                                                                                      ('bc003', '风险加权资产', '根据风险权重调整后的银行资产总额', '风险管理', 'RISK_MANAGEMENT'::business_domain_enum, true),
                                                                                                                      ('bc004', '流动性覆盖率', '银行高质量流动性资产与净现金流出的比率', '流动性管理', 'LIQUIDITY_MANAGEMENT'::business_domain_enum, true),
                                                                                                                      ('bc005', '杠杆率', '一级资本与调整后资产负债表内外资产的比率', '风险管理', 'RISK_MANAGEMENT'::business_domain_enum, true)
ON CONFLICT (concept_name) DO NOTHING;

-- 7.3 插入测试法规文档
INSERT INTO regulation_documents (
    document_id, title, content, regulatory_body, document_type, business_domain,
    document_number, effective_date, status, keywords, abstract, version_number
) VALUES
      (
          'CBIRC-2024-001',
          '商业银行资本充足率管理办法',
          '第一条 为加强商业银行资本监管，提高银行业金融机构抵御风险能力，根据《中华人民共和国银行业监督管理法》等法律法规，制定本办法。第二条 本办法适用于中华人民共和国境内依法设立的商业银行。第三条 商业银行应当建立健全资本管理制度，确保资本充足率持续符合监管要求。核心一级资本充足率不得低于5%，一级资本充足率不得低于6%，资本充足率不得低于8%。',
          'CBIRC'::regulatory_body_enum,
          'DEPARTMENTAL_RULE'::document_type_enum,
          ARRAY['CAPITAL_MANAGEMENT'::business_domain_enum, 'RISK_MANAGEMENT'::business_domain_enum],
          'CBIRC-2024-001',
          '2024-01-01',
          'ACTIVE',
          ARRAY['资本充足率', '商业银行', '监管', '风险管理'],
          '本办法规定了商业银行资本充足率的计算方法和监管要求，旨在加强银行资本监管。',
          '1.0'
      ),
      (
          'PBOC-2024-001',
          '银行间市场流动性管理规定',
          '第一条 为规范银行间市场流动性管理，维护金融市场稳定，根据《中华人民共和国中国人民银行法》等相关法律法规，制定本规定。第二条 银行业金融机构应当建立完善的流动性风险管理体系。第三条 银行应当确保流动性覆盖率不低于100%，净稳定资金比例不低于100%。',
          'PBOC'::regulatory_body_enum,
          'DEPARTMENTAL_RULE'::document_type_enum,
          ARRAY['LIQUIDITY_MANAGEMENT'::business_domain_enum, 'RISK_MANAGEMENT'::business_domain_enum],
          'PBOC-2024-001',
          '2024-02-01',
          'ACTIVE'::document_status_enum,
          ARRAY['流动性管理', '银行间市场', '流动性覆盖率'],
          '本规定明确了银行间市场流动性管理的基本要求和监管标准。',
          '1.0'
      )
ON CONFLICT (document_id) DO NOTHING;

-- 7.4 插入测试条款
INSERT INTO regulation_clauses (
    clause_id, document_id, clause_number, clause_title, clause_content, clause_type, is_key_clause
) VALUES
      (
          'C001', 'CBIRC-2024-001', '第三条', '资本充足率要求',
          '商业银行应当建立健全资本管理制度，确保资本充足率持续符合监管要求。核心一级资本充足率不得低于5%，一级资本充足率不得低于6%，资本充足率不得低于8%。',
          'REQUIREMENT'::clause_type_enum, true
      ),
      (
          'C002', 'CBIRC-2024-001', '第四条', '资本充足率计算',
          '资本充足率 = 总资本 ÷ 风险加权资产。核心一级资本充足率 = 核心一级资本 ÷ 风险加权资产。一级资本充足率 = 一级资本 ÷ 风险加权资产。',
          'CALCULATION'::clause_type_enum, true
      ),
      (
          'C003', 'PBOC-2024-001', '第三条', '流动性指标要求',
          '银行应当确保流动性覆盖率不低于100%，净稳定资金比例不低于100%。',
          'REQUIREMENT'::clause_type_enum, true
      )
ON CONFLICT (clause_id) DO NOTHING;

-- 7.5 插入测试数据字段
INSERT INTO data_fields (
    field_id, document_id, clause_id, field_name, field_code, field_type, field_unit, is_required, description
) VALUES
      (
          'F001', 'CBIRC-2024-001', 'C001', '核心一级资本充足率', 'TIER1_CAR', 'decimal', '%', true, '核心一级资本与风险加权资产的比率'
      ),
      (
          'F002', 'CBIRC-2024-001', 'C001', '一级资本充足率', 'TIER1_CAR_TOTAL', 'decimal', '%', true, '一级资本与风险加权资产的比率'
      ),
      (
          'F003', 'CBIRC-2024-001', 'C001', '资本充足率', 'CAR', 'decimal', '%', true, '总资本与风险加权资产的比率'
      ),
      (
          'F004', 'PBOC-2024-001', 'C003', '流动性覆盖率', 'LCR', 'decimal', '%', true, '高质量流动性资产与净现金流出的比率'
      ),
      (
          'F005', 'PBOC-2024-001', 'C003', '净稳定资金比例', 'NSFR', 'decimal', '%', true, '可用稳定资金与所需稳定资金的比率'
      )
ON CONFLICT (field_id) DO NOTHING;

-- 7.6 插入测试计算公式
INSERT INTO calculation_formulas (
    formula_id, document_id, clause_id, target_field, formula_text, formula_type, description
) VALUES
      (
          'FORM001', 'CBIRC-2024-001', 'C002', '核心一级资本充足率', '核心一级资本充足率 = 核心一级资本 ÷ 风险加权资产', 'SIMPLE', '核心一级资本充足率计算公式'
      ),
      (
          'FORM002', 'CBIRC-2024-001', 'C002', '资本充足率', '资本充足率 = 总资本 ÷ 风险加权资产', 'SIMPLE', '资本充足率计算公式'
      ),
      (
          'FORM003', 'PBOC-2024-001', 'C003', '流动性覆盖率', '流动性覆盖率 = 高质量流动性资产 ÷ 未来30天净现金流出', 'SIMPLE', '流动性覆盖率计算公式'
      )
ON CONFLICT (formula_id) DO NOTHING;

-- 7.7 插入测试合规规则
INSERT INTO compliance_rules (
    rule_id, document_id, clause_id, rule_name, rule_type, description,
    threshold_value, threshold_operator, monitoring_frequency, severity_level
) VALUES
      (
          'RULE001', 'CBIRC-2024-001', 'C001', '核心一级资本充足率最低要求', 'THRESHOLD',
          '核心一级资本充足率不得低于5%', 5.0, '>=', 'MONTHLY', 5
      ),
      (
          'RULE002', 'CBIRC-2024-001', 'C001', '一级资本充足率最低要求', 'THRESHOLD',
          '一级资本充足率不得低于6%', 6.0, '>=', 'MONTHLY', 5
      ),
      (
          'RULE003', 'CBIRC-2024-001', 'C001', '资本充足率最低要求', 'THRESHOLD',
          '资本充足率不得低于8%', 8.0, '>=', 'MONTHLY', 5
      ),
      (
          'RULE004', 'PBOC-2024-001', 'C003', '流动性覆盖率最低要求', 'THRESHOLD',
          '流动性覆盖率不得低于100%', 100.0, '>=', 'DAILY', 4
      ),
      (
          'RULE005', 'PBOC-2024-001', 'C003', '净稳定资金比例最低要求', 'THRESHOLD',
          '净稳定资金比例不得低于100%', 100.0, '>=', 'QUARTERLY', 4
      )
ON CONFLICT (rule_id) DO NOTHING;

-- 7.8 创建管理员用户
INSERT INTO users (user_id, username, email, password_hash, full_name, role) VALUES
                                                                                 (
                                                                                     'admin001', 'admin', 'admin@regulation.system',
                                                                                     '$2a$10$N9qo8uLOickgx2ZMRZoMye1VdGGGEWOFgHlZ0EcQLQ1w8MWFH4ZCK', -- password: admin123
                                                                                     '系统管理员', 'ADMIN'
                                                                                 ),
                                                                                 (
                                                                                     'user001', 'analyst', 'analyst@regulation.system',
                                                                                     '$2a$10$N9qo8uLOickgx2ZMRZoMye1VdGGGEWOFgHlZ0EcQLQ1w8MWFH4ZCK', -- password: admin123
                                                                                     '合规分析师', 'USER'
                                                                                 )
ON CONFLICT (username) DO NOTHING;

-- =============================================================================
-- 8. 设置权限
-- =============================================================================

-- 为应用用户授予所有表的权限
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO regulation_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO regulation_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO regulation_user;

-- 为只读用户授予查询权限
GRANT SELECT ON ALL TABLES IN SCHEMA public TO regulation_readonly;

-- 设置默认权限（对新创建的表也生效）
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO regulation_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO regulation_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO regulation_user;

-- =============================================================================
-- 9. 创建视图
-- =============================================================================

-- 9.1 法规文档摘要视图
CREATE OR REPLACE VIEW v_regulation_summary AS
SELECT
    d.document_id,
    d.title,
    d.regulatory_body,
    d.document_type,
    d.business_domain,
    d.effective_date,
    d.status,
    d.abstract,
    COUNT(c.clause_id) as clause_count,
    COUNT(df.field_id) as field_count,
    COUNT(cr.rule_id) as rule_count
FROM regulation_documents d
         LEFT JOIN regulation_clauses c ON d.document_id = c.document_id
         LEFT JOIN data_fields df ON d.document_id = df.document_id
         LEFT JOIN compliance_rules cr ON d.document_id = cr.document_id
GROUP BY d.document_id, d.title, d.regulatory_body, d.document_type,
         d.business_domain, d.effective_date, d.status, d.abstract;

-- 9.2 活跃法规统计视图
CREATE OR REPLACE VIEW v_active_regulations_stats AS
SELECT
    regulatory_body,
    document_type,
    COUNT(*) as document_count,
    COUNT(CASE WHEN effective_date > CURRENT_DATE - INTERVAL '1 year' THEN 1 END) as recent_count,
    MIN(effective_date) as earliest_date,
    MAX(effective_date) as latest_date
FROM regulation_documents
WHERE status = 'ACTIVE'
GROUP BY regulatory_body, document_type
ORDER BY regulatory_body, document_count DESC;

-- 9.3 合规规则监控视图
CREATE OR REPLACE VIEW v_compliance_monitoring AS
SELECT
    d.title as document_title,
    d.regulatory_body,
    cr.rule_name,
    cr.rule_type,
    cr.threshold_value,
    cr.threshold_operator,
    cr.monitoring_frequency,
    cr.severity_level,
    cr.is_active
FROM compliance_rules cr
         JOIN regulation_documents d ON cr.document_id = d.document_id
WHERE cr.is_active = true AND d.status = 'ACTIVE'
ORDER BY cr.severity_level DESC, d.regulatory_body;

-- 9.4 业务概念使用统计视图
CREATE OR REPLACE VIEW v_concept_usage_stats AS
SELECT
    bc.concept_name,
    bc.category,
    bc.business_domain,
    bc.usage_frequency,
    COUNT(DISTINCT c.document_id) as document_usage_count,
    ARRAY_AGG(DISTINCT d.title) as used_in_documents
FROM business_concepts bc
         LEFT JOIN regulation_clauses c ON bc.concept_name = ANY(c.business_concepts)
         LEFT JOIN regulation_documents d ON c.document_id = d.document_id
GROUP BY bc.concept_id, bc.concept_name, bc.category, bc.business_domain, bc.usage_frequency
ORDER BY bc.usage_frequency DESC;

-- =============================================================================
-- 10. 创建函数
-- =============================================================================

-- 10.1 更新时间戳函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 10.2 为相关表创建更新时间戳触发器
CREATE TRIGGER trigger_regulation_documents_updated_at
    BEFORE UPDATE ON regulation_documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_regulation_clauses_updated_at
    BEFORE UPDATE ON regulation_clauses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_data_fields_updated_at
    BEFORE UPDATE ON data_fields
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_calculation_formulas_updated_at
    BEFORE UPDATE ON calculation_formulas
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_compliance_rules_updated_at
    BEFORE UPDATE ON compliance_rules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_business_concepts_updated_at
    BEFORE UPDATE ON business_concepts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_system_config_updated_at
    BEFORE UPDATE ON system_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 10.3 全文搜索函数
CREATE OR REPLACE FUNCTION search_regulations(search_term TEXT)
    RETURNS TABLE (
                      document_id VARCHAR(50),
                      title VARCHAR(1000),
                      regulatory_body regulatory_body_enum,
                      match_type TEXT,
                      match_content TEXT,
                      rank REAL
                  ) AS $$
BEGIN
    RETURN QUERY
        -- 搜索文档标题
        SELECT
            d.document_id,
            d.title,
            d.regulatory_body,
            'title'::TEXT as match_type,
            d.title as match_content,
            ts_rank(to_tsvector('chinese_simple', d.title), plainto_tsquery('chinese_simple', search_term)) as rank
        FROM regulation_documents d
        WHERE to_tsvector('chinese_simple', d.title) @@ plainto_tsquery('chinese_simple', search_term)
          AND d.status = 'ACTIVE'

        UNION ALL

        -- 搜索文档内容
        SELECT
            d.document_id,
            d.title,
            d.regulatory_body,
            'content'::TEXT as match_type,
            LEFT(d.content, 200) as match_content,
            ts_rank(to_tsvector('chinese_simple', d.content), plainto_tsquery('chinese_simple', search_term)) as rank
        FROM regulation_documents d
        WHERE to_tsvector('chinese_simple', d.content) @@ plainto_tsquery('chinese_simple', search_term)
          AND d.status = 'ACTIVE'

        UNION ALL

        -- 搜索条款内容
        SELECT
            d.document_id,
            d.title,
            d.regulatory_body,
            'clause'::TEXT as match_type,
            c.clause_content as match_content,
            ts_rank(to_tsvector('chinese_simple', c.clause_content), plainto_tsquery('chinese_simple', search_term)) as rank
        FROM regulation_documents d
                 JOIN regulation_clauses c ON d.document_id = c.document_id
        WHERE to_tsvector('chinese_simple', c.clause_content) @@ plainto_tsquery('chinese_simple', search_term)
          AND d.status = 'ACTIVE'

        ORDER BY rank DESC, match_type;
END;
$$ LANGUAGE plpgsql;

-- 10.4 获取文档统计信息函数
CREATE OR REPLACE FUNCTION get_document_stats()
    RETURNS TABLE (
                      total_documents INTEGER,
                      active_documents INTEGER,
                      total_clauses INTEGER,
                      total_rules INTEGER,
                      recent_documents INTEGER
                  ) AS $$
BEGIN
    RETURN QUERY
        SELECT
            COUNT(*)::INTEGER as total_documents,
            COUNT(CASE WHEN status = 'ACTIVE' THEN 1 END)::INTEGER as active_documents,
            (SELECT COUNT(*)::INTEGER FROM regulation_clauses) as total_clauses,
            (SELECT COUNT(*)::INTEGER FROM compliance_rules WHERE is_active = true) as total_rules,
            COUNT(CASE WHEN created_at > CURRENT_DATE - INTERVAL '30 days' THEN 1 END)::INTEGER as recent_documents
        FROM regulation_documents;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 11. 数据验证和清理
-- =============================================================================

-- 11.1 验证数据完整性
DO $$
    DECLARE
        doc_count INTEGER;
        clause_count INTEGER;
        field_count INTEGER;
        rule_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO doc_count FROM regulation_documents;
        SELECT COUNT(*) INTO clause_count FROM regulation_clauses;
        SELECT COUNT(*) INTO field_count FROM data_fields;
        SELECT COUNT(*) INTO rule_count FROM compliance_rules;

        RAISE NOTICE '数据初始化完成:';
        RAISE NOTICE '- 法规文档: % 个', doc_count;
        RAISE NOTICE '- 法规条款: % 个', clause_count;
        RAISE NOTICE '- 数据字段: % 个', field_count;
        RAISE NOTICE '- 合规规则: % 个', rule_count;
    END;
$$;

-- 11.2 更新统计信息
ANALYZE regulation_documents;
ANALYZE regulation_clauses;
ANALYZE data_fields;
ANALYZE calculation_formulas;
ANALYZE compliance_rules;
ANALYZE business_concepts;

-- =============================================================================
-- 12. 连接到测试数据库进行基础配置
-- =============================================================================

\c regulation_test_db;

-- 为测试数据库创建基础扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- 为测试用户授权
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO regulation_test_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO regulation_test_user;

-- 创建测试数据库的基础表结构（简化版）
CREATE TABLE IF NOT EXISTS test_regulation_documents (
                                                         document_id VARCHAR(50) PRIMARY KEY,
                                                         title VARCHAR(1000) NOT NULL,
                                                         content TEXT,
                                                         created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 插入测试数据
INSERT INTO test_regulation_documents (document_id, title, content) VALUES
                                                                        ('TEST-001', '测试法规文档', '这是一个用于测试的法规文档内容。'),
                                                                        ('TEST-002', '测试监管规定', '这是另一个测试文档，包含监管相关内容。')
ON CONFLICT (document_id) DO NOTHING;

-- =============================================================================
-- 13. 最终检查和输出
-- =============================================================================

-- 切回主数据库
\c regulation_db;

-- 输出初始化完成信息
DO $$
    BEGIN
        RAISE NOTICE '=============================================================================';
        RAISE NOTICE '监管合规智能系统数据库初始化完成！';
        RAISE NOTICE '=============================================================================';
        RAISE NOTICE '创建的数据库:';
        RAISE NOTICE '- regulation_db (主业务数据库)';
        RAISE NOTICE '- regulation_test_db (测试数据库)';
        RAISE NOTICE '';
        RAISE NOTICE '创建的用户:';
        RAISE NOTICE '- regulation_user (应用用户)';
        RAISE NOTICE '- regulation_test_user (测试用户)';
        RAISE NOTICE '- regulation_readonly (只读用户)';
        RAISE NOTICE '';
        RAISE NOTICE '初始化的表:';
        RAISE NOTICE '- regulation_documents (法规文档)';
        RAISE NOTICE '- regulation_clauses (法规条款)';
        RAISE NOTICE '- data_fields (数据字段)';
        RAISE NOTICE '- calculation_formulas (计算公式)';
        RAISE NOTICE '- compliance_rules (合规规则)';
        RAISE NOTICE '- business_concepts (业务概念)';
        RAISE NOTICE '- parse_tasks (解析任务)';
        RAISE NOTICE '- query_history (查询历史)';
        RAISE NOTICE '- users (用户管理)';
        RAISE NOTICE '- system_config (系统配置)';
        RAISE NOTICE '';
        RAISE NOTICE '创建的索引: 包含性能索引和全文搜索索引';
        RAISE NOTICE '创建的视图: 包含统计和监控视图';
        RAISE NOTICE '创建的函数: 包含搜索和统计函数';
        RAISE NOTICE '=============================================================================';
        RAISE NOTICE '系统已准备就绪，可以开始使用！';
        RAISE NOTICE '=============================================================================';
    END;
$$;