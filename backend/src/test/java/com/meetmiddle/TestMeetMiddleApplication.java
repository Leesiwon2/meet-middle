package com.meetmiddle;

import org.springframework.boot.SpringApplication;

/** compose 없이 Testcontainers 로 앱을 띄울 때: ./gradlew bootTestRun */
public class TestMeetMiddleApplication {

  public static void main(String[] args) {
    SpringApplication.from(MeetMiddleApplication::main)
        .with(TestcontainersConfiguration.class)
        .run(args);
  }
}
