# 백엔드 구조와 코딩 규칙 (BACKEND-GUIDE)

> 상태: 초안 v0.1 / 2026-11-11
> 대상: `backend/` 아래 모든 Java 코드. 버전은 [TECH-STACK.md](TECH-STACK.md), 오류 계약은 [API-ERROR-CONTRACT.md](API-ERROR-CONTRACT.md), DB 규칙은 [../db/README.md](../db/README.md).

## 1. 폴더 구조

```
backend/
 ├─ build.gradle.kts · settings.gradle.kts · gradlew
 └─ src/
    ├─ main/java/com/meetmiddle/
    │   ├─ MeetMiddleApplication.java
    │   ├─ common/              ← 도메인 무관 공통 (다른 도메인에 의존 금지)
    │   │   ├─ error/           ErrorCode, BusinessException, GlobalExceptionHandler
    │   │   ├─ web/             TraceIdFilter, 페이지 응답(PageResponse)
    │   │   ├─ security/        SecurityConfig, JwtProvider, GuestTokenFilter, CurrentActor
    │   │   └─ config/          Clock, Redis, RestClient 공통 설정
    │   ├─ member/              ┐
    │   ├─ room/                │ 도메인 패키지 (DESIGN §7.2)
    │   ├─ participant/         │ 각 도메인 안: api/ · application/ · domain/ · infra/
    │   ├─ recommend/           │
    │   ├─ place/               ┘
    │   └─ external/            ← 외부 API 어댑터 (kakao/, transit/)
    ├─ main/resources/
    │   ├─ application.yml · application-local.yml · application-test.yml
    │   └─ db/migration/        V1__init.sql …
    └─ test/java/com/meetmiddle/ (main 과 같은 패키지 구조 + architecture/)
```

### 도메인 패키지 내부
| 하위 | 담는 것 | 예 |
|---|---|---|
| `api/` | Controller, 요청/응답 DTO(record) | `RoomController`, `CreateRoomRequest`, `RoomResponse` |
| `application/` | 유스케이스 서비스, 트랜잭션 경계 | `RoomService.create()` |
| `domain/` | 엔티티, 값 객체, 도메인 규칙, Repository 인터페이스 | `Room`, `RoomCode`, `Nickname` |
| `infra/` | JPA Repository 구현·쿼리, Redis 어댑터 | `RoomJpaRepository` |

## 2. 의존 방향 (ArchUnit 이 검사, P0-10)

```
api → application → domain ← infra
              ↓
          external (인터페이스: domain 또는 application 에 둔다, 구현: external/)
common ← 모두 (common 은 아무 도메인도 모른다)
```

- 도메인 패키지끼리는 **application 계층을 통해서만** 호출한다. 다른 도메인의 `infra`·엔티티 직접 참조 금지.
- 순환 의존 금지 (예: `room` ↔ `participant` 가 서로를 부르면 안 된다 → 한쪽 방향만, 반대는 이벤트나 ID 참조).

## 3. 절대 규칙

| 금지 | 대신 |
|---|---|
| 엔티티를 Controller 에서 반환 | 응답 DTO(record) 로 변환 |
| `System.out`, `printStackTrace` | SLF4J 로거 |
| `catch (Exception e)` 로 삼키기 | 좁은 예외를 잡고 `BusinessException(ErrorCode)` 로 변환하거나 그대로 던짐 |
| 로그·예외 메시지에 주소·좌표·토큰·비밀번호 | ID 만 로그. 개인정보 마스킹 |
| 비밀값 하드코딩, 기본값 지정 | 환경변수 + 없으면 기동 실패 |
| `LocalDateTime.now()` 직접 호출 | 주입받은 `Clock` 사용 (`Instant.now(clock)`) |
| 문자열 연결 SQL | JPA / JPQL 파라미터 바인딩 |
| 외부 API 를 서비스에서 직접 `RestClient` 로 호출 | `external/` 어댑터 인터페이스 경유 |
| 마이그레이션 파일(이미 적용된 V 파일) 수정 | 새 V 파일 추가 |

## 4. 코딩 관례

- **DTO 는 record.** 요청 DTO 에 Bean Validation(`@NotBlank`, `@Size`) 을 붙이고 Controller 에서 `@Valid`.
- **트랜잭션은 application 계층에만** `@Transactional`. 조회는 `readOnly = true`.
- **엔티티 생성은 정적 팩토리 + 불변식 검사** (`Room.create(title, host, clock)`). 세터 공개 금지, 상태 변경은 의미 있는 메서드(`room.markComputed()`).
- **ID 노출**: 외부에 노출되는 방 식별자는 `code`(6자리). 내부 PK 는 응답에 넣되 추측 가능한 순번으로 권한 판정하지 않는다.
- **현재 행위자**: Controller 파라미터 `CurrentActor`(회원 ID 또는 참여자 ID) 를 ArgumentResolver 로 주입. `SecurityContextHolder` 를 서비스에서 직접 읽지 않는다.
- **시간대**: DB 는 `timestamptz`, Java 는 `Instant`, 응답은 ISO-8601 오프셋 포함(`+09:00`).
- **이름**: 클래스·메서드는 영어 업무 용어(`Room`, `Participant`, `Hub`, `Recommendation`, `Scenario.CHOSEN/WORK/HOME`, `OriginType.HOME/WORK/OTHER`). 용어가 새로 생기면 DESIGN.md 용어를 따른다.

## 5. 테스트

| 종류 | 도구 | 대상 | 위치 |
|---|---|---|---|
| 단위 | JUnit 5 + AssertJ | 도메인 규칙, 점수 계산(`recommend`), 닉네임 정규화 | `*Test` |
| 웹 계층 | `@WebMvcTest` + MockMvc | 요청 검증, 오류 응답 형식, 권한 | `*ControllerTest` |
| 통합 | Testcontainers PostgreSQL + `AbstractIntegrationTest` | Repository, 마이그레이션, 유니크 제약(닉네임 동시 입력) | `*IT` |
| 아키텍처 | ArchUnit | §2 의존 방향, §3 일부 | `architecture/` |
| 외부 API | Stub 서버(WireMock 또는 MockRestServiceServer) | 어댑터 직렬화·타임아웃·오류 변환 | `external/**` |

- 결함을 고치는 `fix` 커밋은 그 결함을 재현하는 테스트를 함께 넣는다.
- 외부 API 를 실제로 호출하는 테스트는 CI 에서 돌리지 않는다 (`@Tag("live")`, 수동 실행).
- 추천 알고리즘은 **고정 소요시간 행렬 → 기대 순위** 형태의 표 기반 테스트로 가중치 변경 영향을 바로 보이게 한다.

## 6. 설정

- `application.yml`: 공통값, 비밀은 `${ENV_VAR}` 참조만.
- `application-local.yml`: 로컬 포트(18080), Fake 외부 클라이언트, Swagger UI 노출.
- `application-test.yml`: Testcontainers, Fake 외부 클라이언트.
- 추천 가중치(`recommend.weights.max/avg/stddev`, `transferPenaltyMinutes`), 후보 수 `K` 는 `@ConfigurationProperties` 로 묶는다.
