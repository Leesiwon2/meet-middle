package com.meetmiddle;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/** 통합 테스트용 컨테이너. 이미지는 infra/compose.yaml 과 같다 (TECH-STACK §5). */
@TestConfiguration(proxyBeanMethods = false)
public class TestcontainersConfiguration {

  static final String POSTGRES_IMAGE = "postgres:18.6-alpine";
  static final String REDIS_IMAGE = "redis:8.8.4-alpine";

  @Bean
  @ServiceConnection
  PostgreSQLContainer postgresContainer() {
    return new PostgreSQLContainer(DockerImageName.parse(POSTGRES_IMAGE));
  }

  @Bean
  @ServiceConnection(name = "redis")
  GenericContainer<?> redisContainer() {
    return new GenericContainer<>(DockerImageName.parse(REDIS_IMAGE)).withExposedPorts(6379);
  }
}
