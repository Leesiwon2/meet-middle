-- V1: 초기 스키마 (P0-05)
-- 초안: docs/prd/DESIGN.md §8 · 규칙: docs/db/README.md
-- ⚠️ main 에 들어간 뒤에는 이 파일을 수정하지 않는다. 변경은 새 V 파일로.

-- 회원 ------------------------------------------------------------------------
-- 탈퇴 = 행 익명화: email·password_hash·주소·좌표를 NULL 로 지우고 deleted_at 기록.
-- 행은 남겨 participant.member_id·room.host_member_id FK 를 유지한다 (docs/db/README.md §3).
CREATE TABLE member (
  id             BIGSERIAL     PRIMARY KEY,
  email          VARCHAR(255),                     -- 소문자 정규화 후 저장. 탈퇴 시 NULL
  password_hash  VARCHAR(255),                     -- BCrypt. 소셜 로그인·탈퇴 회원은 NULL
  nickname       VARCHAR(20)   NOT NULL,           -- 전역 유일 아님
  home_address   VARCHAR(255),
  home_lat       DOUBLE PRECISION,
  home_lng       DOUBLE PRECISION,
  work_address   VARCHAR(255),
  work_lat       DOUBLE PRECISION,
  work_lng       DOUBLE PRECISION,
  deleted_at     TIMESTAMPTZ,                      -- 탈퇴(익명화) 시각
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
  CONSTRAINT uq_member_email UNIQUE (email),
  CONSTRAINT ck_member_email_required CHECK (deleted_at IS NOT NULL OR email IS NOT NULL),
  CONSTRAINT ck_member_withdrawn_anonymized CHECK (
    deleted_at IS NULL OR (
      email IS NULL AND password_hash IS NULL
      AND home_address IS NULL AND home_lat IS NULL AND home_lng IS NULL
      AND work_address IS NULL AND work_lat IS NULL AND work_lng IS NULL))
);

-- 후보 장소(역) -------------------------------------------------------------------
-- room.confirmed_hub_id 가 참조하므로 room 보다 먼저 만든다. 시드는 V2 (P0-22).
CREATE TABLE hub (
  id          BIGSERIAL        PRIMARY KEY,
  name        VARCHAR(50)      NOT NULL,           -- "사당역"
  lat         DOUBLE PRECISION NOT NULL,
  lng         DOUBLE PRECISION NOT NULL,
  lines       VARCHAR(100),                        -- "2,4"
  region      VARCHAR(20)      NOT NULL,           -- SEOUL | GYEONGGI | INCHEON
  hub_weight  NUMERIC(3,2)     NOT NULL DEFAULT 1.00,
  active      BOOLEAN          NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ      NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ      NOT NULL DEFAULT now(),
  CONSTRAINT uq_hub_name UNIQUE (name),
  CONSTRAINT ck_hub_region CHECK (region IN ('SEOUL', 'GYEONGGI', 'INCHEON')),
  CONSTRAINT ck_hub_weight CHECK (hub_weight BETWEEN 0.80 AND 1.20),
  CONSTRAINT ck_hub_coordinate CHECK (lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180)
);

-- 방 --------------------------------------------------------------------------
CREATE TABLE room (
  id                BIGSERIAL    PRIMARY KEY,
  code              CHAR(6)      NOT NULL,         -- 영대문자+숫자, 혼동 문자(0/O, 1/I/L) 제외
  title             VARCHAR(50)  NOT NULL,
  memo              VARCHAR(200),
  host_member_id    BIGINT       NOT NULL REFERENCES member (id),
  status            VARCHAR(16)  NOT NULL DEFAULT 'OPEN',
  confirmed_hub_id  BIGINT       REFERENCES hub (id),
  max_participants  SMALLINT     NOT NULL DEFAULT 10,
  expires_at        TIMESTAMPTZ  NOT NULL,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT uq_room_code UNIQUE (code),
  CONSTRAINT ck_room_status CHECK (status IN ('OPEN', 'COMPUTED', 'CONFIRMED')),
  CONSTRAINT ck_room_confirmed_hub CHECK (status <> 'CONFIRMED' OR confirmed_hub_id IS NOT NULL),
  CONSTRAINT ck_room_max_participants CHECK (max_participants BETWEEN 2 AND 10)
);

CREATE INDEX ix_room_host_member_id ON room (host_member_id);
CREATE INDEX ix_room_expires_at ON room (expires_at);  -- 만료·주소 삭제 배치

-- 참여자 ------------------------------------------------------------------------
-- region(동 단위)만 다른 참여자에게 공개. 주소·좌표는 본인과 서버만 (DESIGN §9.4).
CREATE TABLE participant (
  id                   BIGSERIAL    PRIMARY KEY,
  room_id              BIGINT       NOT NULL REFERENCES room (id) ON DELETE CASCADE,
  member_id            BIGINT       REFERENCES member (id),     -- 비회원이면 NULL
  guest_token_hash     CHAR(64),                                -- 비회원 토큰 SHA-256 (hex)
  nickname             VARCHAR(20)  NOT NULL,
  nickname_normalized  VARCHAR(20)  NOT NULL,                   -- trim + lower
  home_address         VARCHAR(255),
  home_region          VARCHAR(50),                             -- 공개용 "관악구 봉천동"
  home_lat             DOUBLE PRECISION,
  home_lng             DOUBLE PRECISION,
  work_address         VARCHAR(255),
  work_region          VARCHAR(50),
  work_lat             DOUBLE PRECISION,
  work_lng             DOUBLE PRECISION,
  other_address        VARCHAR(255),                            -- 기타: 이번 모임용, 프로필에 없음
  other_region         VARCHAR(50),
  other_lat            DOUBLE PRECISION,
  other_lng            DOUBLE PRECISION,
  origin_choice        VARCHAR(8),                              -- HOME | WORK | OTHER, NULL = 미선택
  joined_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
  -- ★ 방 단위 닉네임 중복 방지. 백엔드가 이 이름으로 409 NICKNAME_TAKEN 매핑 (API-ERROR-CONTRACT)
  CONSTRAINT uq_room_nickname UNIQUE (room_id, nickname_normalized),
  CONSTRAINT uq_room_member UNIQUE (room_id, member_id),        -- 회원은 방당 1회 참여
  CONSTRAINT uq_participant_guest_token_hash UNIQUE (guest_token_hash),
  CONSTRAINT ck_participant_origin_choice CHECK (origin_choice IN ('HOME', 'WORK', 'OTHER')),
  CONSTRAINT ck_participant_identity CHECK (
    (member_id IS NOT NULL AND guest_token_hash IS NULL) OR
    (member_id IS NULL AND guest_token_hash IS NOT NULL))
);

-- room_id 단독 조회는 uq_room_nickname(room_id, …) 인덱스가 담당한다.
CREATE INDEX ix_participant_member_id ON participant (member_id);

-- 추천 결과 ---------------------------------------------------------------------
-- 방별 덮어쓰기(재계산 시 삭제 후 삽입). detail 에 좌표·지역을 저장하지 않는다 (DESIGN §8, §9.4).
CREATE TABLE recommendation (
  id           BIGSERIAL     PRIMARY KEY,
  room_id      BIGINT        NOT NULL REFERENCES room (id) ON DELETE CASCADE,
  scenario     VARCHAR(8)    NOT NULL,             -- CHOSEN | WORK | HOME
  rank         SMALLINT      NOT NULL,             -- 1..3
  hub_id       BIGINT        NOT NULL REFERENCES hub (id),
  score        NUMERIC(8,2)  NOT NULL,
  max_minutes  SMALLINT      NOT NULL,
  avg_minutes  NUMERIC(5,1)  NOT NULL,
  detail       JSONB         NOT NULL,             -- [{participantId, minutes, transfers, originType, originFallback}]
  computed_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
  CONSTRAINT uq_recommendation_room_scenario_rank UNIQUE (room_id, scenario, rank),
  CONSTRAINT ck_recommendation_scenario CHECK (scenario IN ('CHOSEN', 'WORK', 'HOME')),
  CONSTRAINT ck_recommendation_rank CHECK (rank BETWEEN 1 AND 3)
);

CREATE INDEX ix_recommendation_hub_id ON recommendation (hub_id);
