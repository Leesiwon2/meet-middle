package com.meetmiddle.db;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.meetmiddle.TestcontainersConfiguration;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

/** V1 스키마가 빈 DB 에 적용되고 핵심 제약이 동작하는지 확인한다 (P0-05). */
@SpringBootTest
@ActiveProfiles("test")
@Import(TestcontainersConfiguration.class)
class MigrationIT {

  @Autowired JdbcTemplate jdbc;

  long roomId;

  @BeforeEach
  void setUp() {
    jdbc.execute("TRUNCATE recommendation, participant, room, hub, member RESTART IDENTITY CASCADE");
    long hostId =
        jdbc.queryForObject(
            "INSERT INTO member (email, password_hash, nickname) VALUES ('host@example.com', 'x', '방장') RETURNING id",
            Long.class);
    roomId =
        jdbc.queryForObject(
            "INSERT INTO room (code, title, host_member_id, expires_at)"
                + " VALUES ('ABC234', '모임', ?, now() + interval '14 days') RETURNING id",
            Long.class,
            hostId);
  }

  @Test
  void v1IsAppliedOnce() {
    var versions =
        jdbc.queryForList(
            "SELECT version FROM flyway_schema_history WHERE success ORDER BY installed_rank",
            String.class);
    assertThat(versions).containsExactly("1");
  }

  @Test
  void nicknameIsUniquePerRoomOnly() {
    insertGuest(roomId, "민수", "a");

    assertThatThrownBy(() -> insertGuest(roomId, "민수", "b"))
        .isInstanceOf(DataIntegrityViolationException.class)
        .hasMessageContaining("uq_room_nickname");

    long otherRoom =
        jdbc.queryForObject(
            "INSERT INTO room (code, title, host_member_id, expires_at)"
                + " SELECT 'XYZ789', '다른 모임', host_member_id, expires_at FROM room WHERE id = ?"
                + " RETURNING id",
            Long.class,
            roomId);
    insertGuest(otherRoom, "민수", "c");
  }

  @Test
  void participantMustBeEitherMemberOrGuest() {
    assertThatThrownBy(
            () ->
                jdbc.update(
                    "INSERT INTO participant (room_id, nickname, nickname_normalized) VALUES (?, '유령', '유령')",
                    roomId))
        .isInstanceOf(DataIntegrityViolationException.class)
        .hasMessageContaining("ck_participant_identity");
  }

  @Test
  void withdrawnMemberMustBeAnonymized() {
    assertThatThrownBy(
            () ->
                jdbc.update(
                    "UPDATE member SET deleted_at = now() WHERE email = 'host@example.com'"))
        .isInstanceOf(DataIntegrityViolationException.class)
        .hasMessageContaining("ck_member_withdrawn_anonymized");

    jdbc.update(
        "UPDATE member SET deleted_at = now(), email = NULL, password_hash = NULL"
            + " WHERE email = 'host@example.com'");
    assertThat(jdbc.queryForObject("SELECT count(*) FROM room WHERE id = ?", Long.class, roomId))
        .isEqualTo(1);
  }

  @Test
  void enumLikeColumnsRejectUnknownValues() {
    assertThatThrownBy(() -> jdbc.update("UPDATE room SET status = 'CLOSED' WHERE id = ?", roomId))
        .isInstanceOf(DataIntegrityViolationException.class)
        .hasMessageContaining("ck_room_status");
  }

  private void insertGuest(long room, String nickname, String tokenSeed) {
    jdbc.update(
        "INSERT INTO participant (room_id, guest_token_hash, nickname, nickname_normalized)"
            + " VALUES (?, encode(sha256(?::bytea), 'hex'), ?, lower(trim(?)))",
        room,
        tokenSeed,
        nickname,
        nickname);
  }
}
