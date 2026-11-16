package com.meetmiddle.common.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

/**
 * 임시 보안 설정 (P0-04).
 *
 * <p>health 만 공개하고 나머지는 모두 막는다. 경로별 공개/회원/참여자 구분, JWT·참여 토큰 필터, CORS, CSRF 는 P0-08
 * 에서 이 클래스를 대체한다.
 */
@Configuration(proxyBeanMethods = false)
public class SecurityConfig {

  @Bean
  SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    http.authorizeHttpRequests(
            auth -> auth.requestMatchers("/actuator/health").permitAll().anyRequest().denyAll())
        .httpBasic(basic -> basic.disable())
        .formLogin(form -> form.disable());
    return http.build();
  }
}
