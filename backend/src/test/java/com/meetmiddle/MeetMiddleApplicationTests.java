package com.meetmiddle;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.web.client.RestClient;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@Import(TestcontainersConfiguration.class)
class MeetMiddleApplicationTests {

  @LocalServerPort int port;

  @Test
  void healthIsUpWithDbAndRedis() {
    String body =
        RestClient.create("http://localhost:" + port)
            .get()
            .uri("/actuator/health")
            .retrieve()
            .body(String.class);

    assertThat(body).contains("\"status\":\"UP\"").contains("\"db\"").contains("\"redis\"");
  }

  @Test
  void otherPathsAreDenied() {
    var status =
        RestClient.create("http://localhost:" + port)
            .get()
            .uri("/anything")
            .exchange((req, res) -> res.getStatusCode());

    assertThat(status.is4xxClientError()).isTrue();
  }
}
