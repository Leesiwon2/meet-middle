# 중간지점 (가칭: meet-middle) — 기획/설계 문서

> 작성일: 2026-11-11 · 상태: 초안 v0.1
> 스택: React (Vite + TypeScript) / Spring Boot 3 (Java 21) / PostgreSQL / Redis

---

## 1. 개요

### 1.1 문제
친구들끼리 약속을 잡을 때 사는 곳·회사 위치가 제각각이라 "어디서 만나지?"를 정하는 데 시간이 오래 걸린다.
지도상 가운데는 실제 대중교통으로는 불공평하거나(한 명만 1시간 30분), 만날 곳이 마땅치 않은 위치(한강, 주택가)인 경우가 많다.

### 1.2 해결
1. 한 명이 방을 만들고 **링크를 공유**한다.
2. 링크로 들어온 사람은 **로그인 또는 비회원(닉네임)** 으로 참여해 **집·회사 주소**를 입력한다.
3. 서비스가 **대중교통 소요시간 기준**으로 가장 공평한 만남 장소를 추천한다.
   - **회사 출발(평일 퇴근 후)** / **집 출발(주말)** 두 시나리오를 모두 계산해 비교해서 보여준다.
4. 선택한 장소 주변의 **맛집·술집**을 추천한다.

### 1.3 목표 / 비목표 (MVP 기준)
| 목표 | 비목표 (후속) |
|---|---|
| 링크 하나로 2~10명이 참여 | 일정(날짜) 조율 |
| 대중교통 기준 공평한 장소 Top 3 | 자가용·도보 기준 계산 |
| 집/회사 시나리오 비교 | 실시간 도착 정보 반영 |
| 주변 맛집·술집 목록 | 자체 리뷰·평점 시스템, 예약 |
| 수도권 지원 | 전국 지원 (후보 역 DB 확장으로 대응) |

---

## 2. 사용자와 핵심 시나리오

### 2.1 사용자 유형
| 유형 | 할 수 있는 것 |
|---|---|
| **회원** | 방 생성(방장), 방 참여, 프로필에 집/회사 주소 저장 → 참여 시 자동 입력, 내 방 목록 |
| **비회원** | **링크로만** 방 참여 가능. 닉네임 입력, 주소 입력. 방 생성 불가 |

> 방 생성은 회원만 가능 → 스팸 방 생성 방지 + 방장 식별. (미결정 사항 §11 참고)

### 2.2 대표 시나리오
1. 지원(회원)이 "11월 송년회" 방 생성 → 링크 `https://.../r/K7Q2MX` 를 단톡방에 공유
2. 친구 A(비회원)가 링크 클릭 → 닉네임 "민수" 입력 → 중복 검사 통과 → 집/회사 주소 입력
3. 친구 B(회원)가 링크 클릭 → 로그인 → 프로필 주소 자동 입력 → 확인
4. 참여자들이 대기 화면에서 "4명 중 3명 입력 완료" 를 실시간으로 확인
5. 방장이 **[중간지점 찾기]** → 결과 화면
   - 탭: **퇴근 후 (회사 출발)** / **주말 (집 출발)**
   - 각 탭에 추천 장소 Top 3 + 참여자별 소요시간
6. "사당역" 선택 → 주변 맛집 / 술집 / 카페 목록 → 카카오맵 링크로 이동

---

## 3. 기능 요구사항

`[M]` = MVP, `[L]` = 후속

### 3.1 인증
- `[M]` 회원가입/로그인: 이메일 + 비밀번호
- `[L]` 카카오 소셜 로그인 (단톡방 공유 흐름과 궁합이 좋아 우선순위 높음)
- `[M]` 회원 프로필: 기본 닉네임, 집 주소, 회사 주소 (선택)

### 3.2 방
- `[M]` 방 생성: 방 이름, (선택) 약속 메모
- `[M]` 방 코드: 6자리 영대문자+숫자, 혼동 문자(0/O, 1/I/L) 제외 → 약 7억 조합
- `[M]` 방 상태: `OPEN`(참여 중) → `COMPUTED`(결과 있음) → `CONFIRMED`(장소 확정)
  - 결과가 나온 후에도 참여/주소 수정 가능 → 상태는 `OPEN`으로 돌아가고 "재계산 필요" 표시
- `[M]` 만료: 생성 후 14일 → 읽기 전용, 30일 후 주소 데이터 삭제 (§9 개인정보)
- `[M]` 인원 제한: 최대 10명 (API 호출량 제어, §5.6)
- `[L]` 방장 위임, 참여자 강퇴

### 3.3 참여 & 닉네임
- `[M]` 비회원 참여: 닉네임 입력(2~10자, 한글/영문/숫자)
- `[M]` **닉네임 중복 검사는 방 단위**
  - 같은 방 안에서만 중복 불가, 다른 방과는 무관
  - 회원도 방 안에서는 "방 닉네임"을 가짐 (기본값 = 프로필 닉네임, 충돌 시 수정 요구)
  - 대소문자/앞뒤 공백 정규화 후 비교 (`" 민수 "` = `"민수"`, `"Tom"` = `"tom"`)
  - DB `UNIQUE(room_id, nickname_normalized)` 로 최종 보장 → 동시 입력 경쟁 상황도 안전
  - 입력 중 실시간 확인: `GET /rooms/{code}/nicknames/check?value=` (UX용, 최종 판단은 INSERT)
- `[M]` 재방문: 비회원은 방별 참여 토큰을 쿠키로 저장 → 같은 브라우저로 다시 열면 본인으로 인식
- `[L]` 비회원 → 회원 전환 시 참여 이력 이전

### 3.4 주소 입력
- `[M]` 집 주소 / 회사 주소 각각 입력 (주소 검색 자동완성 → 좌표 변환)
- `[M]` 둘 중 하나만 입력도 허용
  - 회사 주소 없음 → 회사 시나리오에서 집 주소로 대체 (결과에 "집 기준" 배지 표시)
  - 집 주소 없음 → 반대로 대체
- `[M]` 다른 참여자에게는 **동 단위**까지만 노출 (예: "관악구 봉천동") — 정확한 주소 비공개
- `[L]` "가까운 역" 으로 대충 입력하는 옵션 (주소 공개가 부담스러운 사용자용)

### 3.5 중간지점 추천
- `[M]` 방장이 계산 실행 (최소 2명 주소 입력 시 활성화)
- `[M]` 회사/집 두 시나리오 계산 → 각 Top 3 장소
- `[M]` 각 장소: 역 이름, 참여자별 소요시간·환승 횟수, 최대/평균 시간
- `[M]` 시나리오 비교 요약: "퇴근 후엔 **강남**, 주말엔 **사당**이 가장 공평해요"
- `[L]` 장소 투표, 출발 시각 지정(심야 시간 반영)

### 3.6 맛집·술집 추천
- `[M]` 선택한 장소 반경 500m 내 카테고리별 목록: 음식점 / 술집 / 카페
- `[M]` 이름, 카테고리, 역에서 거리, 카카오맵 장소 링크
- `[L]` 평점 기반 정렬 (외부 데이터 확보 필요, §6.3)
- `[L]` 인원수 고려 필터(단체석), 장소 단톡 공유 카드

### 3.7 실시간성
- `[M]` 대기 화면에서 참여자 목록/입력 현황 갱신: **3초 폴링**으로 시작
- `[L]` SSE 로 전환 (`GET /rooms/{code}/events`)

---

## 4. 화면 설계

```
[S1] 랜딩            [S2] 방 생성          [S3] 링크 공유
┌──────────────┐    ┌──────────────┐     ┌──────────────┐
│ 어디서 만나?  │    │ 방 이름       │     │ 링크 복사     │
│ [방 만들기]   │ →  │ [__________] │  →  │ [카카오 공유] │
│ (로그인 필요) │    │ [만들기]      │     │ → S5로 이동   │
└──────────────┘    └──────────────┘     └──────────────┘

[S4] 링크로 입장 (/r/{code})        [S5] 주소 입력
┌───────────────────────┐          ┌───────────────────────┐
│ "11월 송년회"에 초대됨  │          │ 🏠 집   [주소 검색 🔍] │
│ [로그인하고 참여]       │    →     │ 🏢 회사 [주소 검색 🔍] │
│ ── 또는 ──             │          │ ※ 다른 사람에겐 동까지만│
│ 닉네임 [민수    ] ✓    │          │ [저장]                 │
│ [비회원으로 참여]       │          └───────────────────────┘
└───────────────────────┘

[S6] 대기실                         [S7] 결과
┌───────────────────────┐          ┌───────────────────────────┐
│ 참여자 4명 · 3명 입력 ✓ │          │ [퇴근 후 회사출발] [주말 집출발]│
│ ✓ 지원(방장) 관악구     │          │ 1. 사당역  최대 32분 평균 25분 │
│ ✓ 민수 성동구           │    →     │    지원 18 · 민수 32 · …     │
│ ✓ 영희 분당구           │          │ 2. 교대역  최대 35분 …       │
│ … 철수 (입력 중)        │          │ 3. 강남역  …                 │
│ [중간지점 찾기] (방장)   │          │ [지도 보기]  [이 장소 선택]   │
└───────────────────────┘          └───────────────────────────┘

[S8] 장소 주변 추천
┌───────────────────────┐
│ 사당역 주변            │
│ [맛집] [술집] [카페]    │
│ • ○○고깃집  한식 · 120m │
│ • △△포차   술집 · 250m │
│   → 카카오맵에서 보기    │
└───────────────────────┘
```

---

## 5. 추천 알고리즘

### 5.1 왜 지도상 "가운데"가 아닌가
- 좌표의 무게중심은 강·산·주택가에 찍히기 쉽고, 지하철 노선 구조상 시간이 공평하지 않다.
- → **"만남 장소로 쓰이는 역" 후보군** 중에서 **실제 대중교통 소요시간**으로 고른다.

### 5.2 후보 장소 (Hub) DB
- 수도권 약속 장소로 쓰이는 역 약 **80~100개**를 사전 등록 (`hub` 테이블)
  - 예: 강남, 홍대입구, 합정, 신촌, 종로3가, 을지로3가, 서울역, 용산, 여의도, 영등포, 신도림, 사당, 교대, 잠실, 건대입구, 왕십리, 성수, 노원, 수유, 혜화, 판교, 수원, 부평, 일산(정발산) …
  - 속성: 이름, 좌표, 노선 목록, `hub_weight`(상권 규모 가중치 0.8~1.2)
- 기준: 환승역 + 상권(음식점·술집 밀집) — 초기엔 수작업 큐레이션, 후속으로 카카오 로컬 API 장소 밀도로 자동 보정

### 5.3 계산 절차 (시나리오별로 동일하게 수행)

```
입력: 참여자 P = {p1..pn}, 각 출발 좌표 o_i (시나리오에 따라 집 or 회사)
1) 후보 축소
   - 중심 c = 출발 좌표들의 평균 (참고용)
   - hub 중 c 에서 가까운 순 + 참여자 각자에서 "너무 멀지 않은" hub 로 K=12 개 선정
     (모든 참여자 직선거리 합이 작은 순 → 상위 12)
2) 소요시간 행렬 T[i][k] = 대중교통 소요시간(o_i → hub_k) 조회  ※ 캐시 우선 (§5.5)
3) 점수 계산 (낮을수록 좋음)
     max_k  = max_i T[i][k]          ← 공평성 (가장 오래 걸리는 사람)
     avg_k  = mean_i T[i][k]         ← 전체 효율
     sd_k   = stddev_i T[i][k]       ← 편차
     score_k = (0.5·max_k + 0.3·avg_k + 0.2·sd_k) / hub_weight_k
            + 3분 × (참여자 평균 환승 횟수)
4) score 오름차순 Top 3 반환
   - 동점(±1분)일 경우 hub_weight 높은 쪽 우선
```

- 가중치(0.5/0.3/0.2, 환승 3분)는 `application.yml` 설정값 → 실제 사용 데이터로 튜닝
- 경로 조회 실패(경로 없음/심야)한 참여자–hub 조합은 해당 hub 제외

### 5.4 두 시나리오 비교
- 시나리오 A **회사 출발**: o_i = 회사 (없으면 집)
- 시나리오 B **집 출발**: o_i = 집 (없으면 회사)
- **두 시나리오의 출발지가 모든 참여자에 대해 같으면** (모두 한쪽만 입력) 한 번만 계산하고 탭 하나만 표시
- 결과 요약 문구: 두 시나리오 1위가 같으면 "언제 만나도 **사당**이 가장 좋아요", 다르면 각각 표시

### 5.5 캐싱 & 호출량 최적화
- 출발 좌표를 **약 200m 격자로 스냅** → `(grid_cell, hub_id)` 키로 Redis 캐시, TTL 7일
  - 같은 동네 사람/재계산 시 재호출 없음
- 동일 방 재계산 시: 주소가 바뀐 참여자의 행만 재조회
- 외부 API 동시 호출은 스레드풀(동시성 5) + 타임아웃 3초 + 재시도 1회

### 5.6 호출량 추정
- 최악: 10명 × 12 hub × 2 시나리오 = **240 호출 / 계산 1회**
- 평균(5명, 캐시 적중 40%): 5 × 12 × 2 × 0.6 ≈ **72 호출**
- → 외부 API 일일 한도와 비교해 방 수 상한 산정 필요 (§6 확인 필요)
- **후속 최적화(Phase 2)**: 수도권 전 역(약 600개) × hub(100개) **역간 소요시간 행렬을 사전 계산**해 DB에 저장하고,
  실시간으로는 "출발지 → 가까운 역 2~3곳 접근시간(도보/버스)"만 조회 → 계산당 호출 수를 n × 3 수준으로 축소

---

## 6. 외부 API

| 용도 | API | 비고 |
|---|---|---|
| 주소 검색(자동완성) | 다음 우편번호 서비스(프론트) 또는 카카오 로컬 키워드 검색 | 우편번호 서비스는 무료·키 불필요 |
| 주소 → 좌표 | 카카오 로컬 API `/v2/local/search/address` | REST 키 서버 보관 |
| 대중교통 소요시간 | **ODsay LAB** `searchPubTransPathT` (1순위) / TMAP 대중교통 API (대안) | 카카오·네이버는 대중교통 길찾기 공개 API 없음 |
| 주변 장소 | 카카오 로컬 API 카테고리 검색 (`FD6` 음식점, `CE7` 카페) + 키워드 "술집" | 반경·정렬 지원 |
| 지도 표시 | 카카오맵 JavaScript SDK | 도메인 등록 필요 |

### 6.1 외부 API 추상화
- `TransitClient` 인터페이스 → `OdsayTransitClient`, `TmapTransitClient` 구현체 → 설정으로 교체
- 테스트용 `FakeTransitClient` (직선거리 × 계수로 시간 추정)

### 6.2 확인 필요
- [ ] ODsay 무료/유료 플랜의 일일 호출 한도·상업적 이용 조건
- [ ] TMAP 대중교통 API 요금 체계
- [ ] 카카오 로컬 API 일일 쿼터

### 6.3 맛집 "평점" 한계
- 카카오 로컬 API는 **평점/리뷰 수를 제공하지 않음** → MVP는 거리순 + 카테고리 필터
- 후속 옵션: 네이버 검색(지역) API(결과 수 제한 있음), Google Places API(평점 제공, 유료) 검토

---

## 7. 시스템 아키텍처

```
[브라우저: React SPA]
   │  REST (JSON), 쿠키(회원 JWT / 비회원 참여 토큰)
   ▼
[Spring Boot API] ──── PostgreSQL (회원, 방, 참여자, hub, 계산 결과)
   │         └──────── Redis (소요시간 캐시, 방 조회 캐시, rate limit)
   ├── Kakao Local API
   ├── ODsay / TMAP
   └── (후속) SSE 브로드캐스트
```

### 7.1 프론트엔드 (React)
- Vite + TypeScript, React Router, TanStack Query(폴링·캐시), Zustand(가벼운 전역 상태)
- 스타일: Tailwind CSS · 모바일 우선 (단톡방 링크 → 대부분 모바일 진입)
- 라우트
  - `/` 랜딩 · `/login` · `/signup` · `/me` 프로필
  - `/rooms/new` 방 생성
  - `/r/:code` 입장 → (참여 전) S4 / (참여 후) 대기실 S6
  - `/r/:code/address` 주소 입력 S5
  - `/r/:code/result` 결과 S7 · `/r/:code/places/:hubId` 주변 추천 S8

### 7.2 백엔드 (Spring Boot)
- Java 21, Spring Boot 3.x, Spring Web, Spring Security, Spring Data JPA, Flyway, Redis(Lettuce)
- 패키지 구조 (도메인 중심)
  ```
  com.meetmiddle
   ├─ auth        (회원가입, 로그인, JWT, 비회원 토큰 필터)
   ├─ member
   ├─ room        (방, 방 코드 생성, 상태)
   ├─ participant (참여, 닉네임 검사, 주소)
   ├─ recommend   (hub, 후보 축소, 점수 계산, 결과 저장)
   ├─ place       (주변 장소 조회)
   └─ external    (KakaoLocalClient, TransitClient 구현체)
  ```
- 계산은 MVP에선 **동기 처리**(평균 수 초) + 진행 중 중복 실행 방지 락(Redis `SET NX`)
  - 후속: 비동기 Job + 상태 폴링

---

## 8. 데이터 모델 (PostgreSQL)

```sql
CREATE TABLE member (
  id             BIGSERIAL PRIMARY KEY,
  email          VARCHAR(255) NOT NULL UNIQUE,
  password_hash  VARCHAR(255),              -- 소셜 로그인 회원은 NULL
  nickname       VARCHAR(20)  NOT NULL,     -- 전역 유일 아님
  home_address   VARCHAR(255),
  home_lat       DOUBLE PRECISION,
  home_lng       DOUBLE PRECISION,
  work_address   VARCHAR(255),
  work_lat       DOUBLE PRECISION,
  work_lng       DOUBLE PRECISION,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE room (
  id             BIGSERIAL PRIMARY KEY,
  code           CHAR(6)      NOT NULL UNIQUE,
  title          VARCHAR(50)  NOT NULL,
  memo           VARCHAR(200),
  host_member_id BIGINT       NOT NULL REFERENCES member(id),
  status         VARCHAR(16)  NOT NULL DEFAULT 'OPEN',   -- OPEN | COMPUTED | CONFIRMED
  confirmed_hub_id BIGINT,
  max_participants SMALLINT   NOT NULL DEFAULT 10,
  expires_at     TIMESTAMPTZ  NOT NULL,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE participant (
  id                  BIGSERIAL PRIMARY KEY,
  room_id             BIGINT      NOT NULL REFERENCES room(id) ON DELETE CASCADE,
  member_id           BIGINT      REFERENCES member(id),        -- 비회원이면 NULL
  guest_token_hash    CHAR(64),                                  -- 비회원 토큰 SHA-256
  nickname            VARCHAR(20) NOT NULL,
  nickname_normalized VARCHAR(20) NOT NULL,                      -- trim + lower
  home_address  VARCHAR(255), home_region VARCHAR(50),           -- region: 공개용 "관악구 봉천동"
  home_lat DOUBLE PRECISION,  home_lng DOUBLE PRECISION,
  work_address  VARCHAR(255), work_region VARCHAR(50),
  work_lat DOUBLE PRECISION,  work_lng DOUBLE PRECISION,
  joined_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_room_nickname UNIQUE (room_id, nickname_normalized),   -- ★ 방 단위 닉네임 중복 방지
  CONSTRAINT uq_room_member   UNIQUE (room_id, member_id),             -- 회원은 방당 1회 참여
  CONSTRAINT ck_identity CHECK (
    (member_id IS NOT NULL AND guest_token_hash IS NULL) OR
    (member_id IS NULL AND guest_token_hash IS NOT NULL))
);

CREATE TABLE hub (
  id          BIGSERIAL PRIMARY KEY,
  name        VARCHAR(50)  NOT NULL,          -- "사당역"
  lat         DOUBLE PRECISION NOT NULL,
  lng         DOUBLE PRECISION NOT NULL,
  lines       VARCHAR(100),                   -- "2,4"
  region      VARCHAR(20)  NOT NULL,          -- "SEOUL" | "GYEONGGI" | "INCHEON"
  hub_weight  NUMERIC(3,2) NOT NULL DEFAULT 1.00,
  active      BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE recommendation (
  id           BIGSERIAL PRIMARY KEY,
  room_id      BIGINT      NOT NULL REFERENCES room(id) ON DELETE CASCADE,
  scenario     VARCHAR(8)  NOT NULL,          -- WORK | HOME
  rank         SMALLINT    NOT NULL,          -- 1..3
  hub_id       BIGINT      NOT NULL REFERENCES hub(id),
  score        NUMERIC(8,2) NOT NULL,
  max_minutes  SMALLINT    NOT NULL,
  avg_minutes  NUMERIC(5,1) NOT NULL,
  detail       JSONB       NOT NULL,          -- [{participantId, minutes, transfers, originType}]
  computed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (room_id, scenario, rank)
);
```

- 계산 결과는 방별로 덮어쓰기(재계산 시 기존 행 삭제 후 삽입)
- `detail.originType`: 회사 시나리오인데 집으로 대체된 경우 `HOME` → UI 배지

---

## 9. 인증 · 보안 · 개인정보

### 9.1 회원
- 로그인 성공 시 Access JWT(30분) + Refresh 토큰(14일) → `HttpOnly; Secure; SameSite=Lax` 쿠키
- 비밀번호: BCrypt

### 9.2 비회원 참여 토큰
- 참여 시 서버가 32바이트 랜덤 토큰 생성 → **SHA-256 해시만 DB 저장**
- 쿠키 `pt_{roomCode}` (`HttpOnly`, `Path=/api/rooms/{code}`, 만료 = 방 만료일)
- 요청 시 필터가 쿠키 토큰 → participant 식별. 이 토큰으로는 **해당 방의 본인 참여 정보만** 수정 가능
- 쿠키를 잃으면(다른 기기) 같은 닉네임 재사용 불가 → 새 닉네임으로 참여 (후속: 방장이 정리)

### 9.3 권한 표
| 행위 | 방장 | 참여자(회원/비회원) | 외부인 |
|---|---|---|---|
| 방 정보·참여자 목록(동 단위) 조회 | ✓ | ✓ | 방 제목·인원수만 |
| 본인 주소 수정 | ✓ | ✓ | ✗ |
| 계산 실행·장소 확정 | ✓ | ✗ | ✗ |
| 결과·주변 장소 조회 | ✓ | ✓ | ✗ |

### 9.4 개인정보
- 정확한 주소/좌표는 **본인과 서버만** 접근, API 응답에서 다른 참여자는 `region`(동 단위)만
- 계산 결과 `detail`에도 좌표 저장 안 함 (분 단위 시간만)
- 방 만료 30일 후 participant 주소·좌표 컬럼 NULL 처리 배치
- 회원 프로필 주소는 회원 탈퇴 시 즉시 삭제
- 가입/참여 시 위치정보 수집·이용 동의 문구 (위치정보법 검토 필요)

### 9.5 남용 방지
- 방 코드 추측 방지: 코드 조회 실패 IP당 분당 20회 제한 (Redis)
- 닉네임 검사 API: IP당 분당 60회
- 계산 실행: 방당 1분 1회

---

## 10. API 명세 (REST, prefix `/api`)

### 10.1 인증/회원
| Method | Path | 설명 |
|---|---|---|
| POST | `/auth/signup` | `{email, password, nickname}` |
| POST | `/auth/login` | `{email, password}` → 쿠키 발급 |
| POST | `/auth/refresh` | 토큰 재발급 |
| POST | `/auth/logout` | |
| GET / PATCH | `/me` | 프로필 조회/수정 (주소 포함) |
| GET | `/me/rooms` | 내가 만든/참여한 방 목록 |

### 10.2 방
| Method | Path | 권한 | 설명 |
|---|---|---|---|
| POST | `/rooms` | 회원 | `{title, memo}` → `{code, shareUrl}` · 방장 자동 참여 |
| GET | `/rooms/{code}` | 공개 | 외부인: `{title, participantCount, status}` / 참여자: + `me`, `isHost` |
| GET | `/rooms/{code}/participants` | 참여자 | `[{id, nickname, isHost, homeRegion, workRegion, ready}]` |

### 10.3 참여
| Method | Path | 권한 | 설명 |
|---|---|---|---|
| GET | `/rooms/{code}/nicknames/check?value=민수` | 공개 | `{available: true}` |
| POST | `/rooms/{code}/participants` | 회원 or 비회원 | `{nickname}` → 비회원이면 `pt_{code}` 쿠키 발급. 중복 시 **409 `NICKNAME_TAKEN`** |
| PUT | `/rooms/{code}/participants/me/addresses` | 참여자 본인 | `{home:{address}, work:{address}}` → 서버에서 지오코딩 |
| DELETE | `/rooms/{code}/participants/me` | 참여자 본인 | 방 나가기 |

### 10.4 추천
| Method | Path | 권한 | 설명 |
|---|---|---|---|
| POST | `/rooms/{code}/recommendations` | 방장 | 계산 실행 (동기). 주소 입력자 2명 미만 → 422 |
| GET | `/rooms/{code}/recommendations` | 참여자 | 아래 응답 |
| POST | `/rooms/{code}/confirm` | 방장 | `{hubId}` → `CONFIRMED` |

```json
{
  "computedAt": "2026-11-11T19:00:00+09:00",
  "stale": false,
  "summary": "퇴근 후엔 강남역, 주말엔 사당역이 가장 공평해요",
  "scenarios": [
    {
      "type": "WORK",
      "results": [
        {
          "rank": 1,
          "hub": {"id": 3, "name": "강남역", "lat": 37.4979, "lng": 127.0276},
          "maxMinutes": 31, "avgMinutes": 24.5,
          "participants": [
            {"id": 11, "nickname": "지원", "minutes": 18, "transfers": 0, "originType": "WORK"},
            {"id": 12, "nickname": "민수", "minutes": 31, "transfers": 1, "originType": "HOME"}
          ]
        }
      ]
    },
    { "type": "HOME", "results": [ ... ] }
  ]
}
```

### 10.5 주변 장소
| Method | Path | 권한 | 설명 |
|---|---|---|---|
| GET | `/hubs/{hubId}/places?category=FOOD\|BAR\|CAFE&page=1` | 참여자 | 카카오 로컬 프록시(키 은닉) + Redis 캐시 1일 |

### 10.6 공통 오류 형식
```json
{ "code": "NICKNAME_TAKEN", "message": "이 방에 이미 같은 닉네임이 있어요." }
```
주요 코드: `ROOM_NOT_FOUND`(404), `ROOM_EXPIRED`(410), `ROOM_FULL`(409), `NICKNAME_TAKEN`(409), `NOT_HOST`(403), `ADDRESS_NOT_FOUND`(422), `NOT_ENOUGH_PARTICIPANTS`(422), `TRANSIT_API_UNAVAILABLE`(503)

---

## 11. 미결정 사항
1. **비회원도 방을 만들 수 있게 할지** — 진입 장벽 ↓ vs 스팸·방 관리 ↑ (현재: 회원만)
2. **계산 실행 권한** — 방장만 vs 아무 참여자나 (현재: 방장만)
3. **대중교통 API 선정** — ODsay vs TMAP: 한도·요금 확인 후 결정 (§6.2)
4. **출발 시각 반영 여부** — 퇴근 시나리오는 평일 19시, 주말 시나리오는 토요일 14시 기준으로 고정할지
5. **지원 지역** — 수도권 한정으로 시작해도 되는지
6. **서비스 이름**

---

## 12. 마일스톤 (안)
| 단계 | 내용 | 산출물 |
|---|---|---|
| M0 | 외부 API 키 발급, ODsay/TMAP 비교 테스트, hub 80개 데이터 정리 | 비교 결과, `hub` 시드 SQL |
| M1 | 백엔드 골격: 회원/JWT, 방·참여·닉네임 검사, 주소 지오코딩 | API + 테스트 |
| M2 | 추천 엔진: 후보 축소, 소요시간 조회+캐시, 점수 계산, 두 시나리오 | 추천 API, 가중치 설정 |
| M3 | 프론트: S1~S7 화면, 폴링 | 동작하는 MVP |
| M4 | 주변 장소(S8), 카카오맵 표시, 공유 | MVP 완성 |
| M5 | 실사용 테스트(친구 그룹), 가중치 튜닝, 카카오 로그인 | v1.0 |
