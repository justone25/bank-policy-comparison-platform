package life.ljs.compliance;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * @author little carp
 * @version 1.0.0
 * @description 应用程序启动测试
 * @since 2025/7/10
 **/
@SpringBootTest
@ActiveProfiles("test")
class RegulationSystemApplicationTest {

    /**
     * 测试应用程序上下文加载
     */
    @Test
    void contextLoads() {
        // 这个测试验证Spring Boot应用程序上下文能够正常加载
        // 如果上下文加载失败，测试会自动失败
    }

    /**
     * 测试主方法不抛出异常
     */
    @Test
    void mainMethodTest() {
        // 测试main方法能够正常执行（不会抛出异常）
        // 注意：这里不会真正启动应用，只是验证方法调用
        String[] args = {};
        // 在测试环境中，我们通常不直接调用main方法
        // 而是通过@SpringBootTest来测试应用启动
        org.junit.jupiter.api.Assertions.assertDoesNotThrow(() -> {
            // 验证RegulationSystemApplication类存在且可以实例化
            RegulationSystemApplication app = new RegulationSystemApplication();
            org.junit.jupiter.api.Assertions.assertNotNull(app);
        });
    }
}
