# API 응답·오류 계약 (API-ERROR-CONTRACT)

> 상태: 초안 v0.1 / 2026-11-11
> 역할: 백엔드와 프론트가 공유하는 **성공 응답 형식, 오류 형식, 오류 코드 목록**의 정본. 코드 목록을 바꾸면 백엔드 `ErrorCode` enum 과 프론트 `api/errors.ts` 매핑을 같은 PR 에서 고친다.

## 1. 성공 응답

- **봉투(envelope) 없이 리소스를 그대로 반환한다.** (`{ "data": … }` 로 감싸지 않음 → orval 타입이 단순해진다)
- 목록 + 페이지:
  ```json
  { "items": [ … ], "page": 1, "size": 20, "total": 57 }
  ```
- 생성은 `201 Created` + 생성된 리소스, 본문 없는 성공은 `204 No Content`.
- 시간은 ISO-8601 오프셋 포함 문자열 (`2026-11-11T19:00:00+09:00`).

## 2. 오류 응답 — RFC 9457 ProblemDetail

`Content-Type: application/problem+json`

```json
{
  "type": "about:blank",
  "title": "Conflict",
  "status": 409,
  "detail": "이 방에 이미 같은 닉네임이 있어요.",
  "instance": "/api/rooms/K7Q2MX/participants",
  "code": "NICKNAME_TAKEN",
  "traceId": "7f3a9c1e5b2d4a60",
  "errors": [
    { "field": "nickname", "code": "NICKNAME_TAKEN", "message": "이 방에 이미 같은 닉네임이 있어요." }
  ]
}
```

| 필드 | 필수 | 뜻 |
|---|---|---|
| `status` | ✓ | HTTP 상태 |
| `code` | ✓ | **프론트가 분기하는 유일한 기준.** 대문자 스네이크 |
| `detail` | ✓ | 사용자에게 보여줘도 되는 한국어 문장. 프론트는 이 문자열로 분기하지 않는다 |
| `traceId` | ✓ | 로그 추적 ID (응답 헤더 `X-Trace-Id` 와 동일) |
| `errors` | | 필드 단위 오류 (검증 실패, 필드에 귀속되는 업무 오류) |

### 절대 포함하지 않는 것
stack trace, SQL, 제약조건 이름, 클래스 이름, 토큰, 주소·좌표 등 개인정보.

## 3. 오류 코드 목록

| code | HTTP | 언제 | 프론트 처리 | 재시도 |
|---|---|---|---|---|
| `VALIDATION_FAILED` | 400 | 요청 형식·필드 검증 실패 | 필드 오류 표시 | ✗ |
| `UNAUTHENTICATED` | 401 | 로그인 필요 / 토큰 만료·위조 | 로그인 화면 (refresh 1회 시도 후) | ✗ |
| `FORBIDDEN` | 403 | 권한 없음 (CSRF 실패 포함) | 안내 화면 | ✗ |
| `NOT_HOST` | 403 | 방장 전용 행위 | 버튼 숨김 + 안내 | ✗ |
| `NOT_PARTICIPANT` | 403 | 참여하지 않은 방의 상세 접근 | 입장 화면(S4)으로 | ✗ |
| `ROOM_NOT_FOUND` | 404 | 방 코드 없음 | "없는 방이에요" 화면 | ✗ |
| `ROOM_EXPIRED` | 410 | 만료된 방 | "만료된 방이에요" 화면 | ✗ |
| `ROOM_FULL` | 409 | 인원 초과 | 안내 | ✗ |
| `NICKNAME_TAKEN` | 409 | 방 안 닉네임 중복 (DB 유니크 위반 포함) | 닉네임 칸 오류 | ✗ |
| `ALREADY_JOINED` | 409 | 회원이 같은 방 재참여 | 대기실로 이동 | ✗ |
| `EMAIL_TAKEN` | 409 | 가입 이메일 중복 | 이메일 칸 오류 | ✗ |
| `ADDRESS_NOT_FOUND` | 422 | 주소 → 좌표 변환 실패 | 주소 칸 오류 | ✗ |
| `ORIGIN_ADDRESS_MISSING` | 422 | 고른 출발지(집/회사/기타)의 주소가 비어 있음 | 출발지 선택 칸 오류 | ✗ |
| `NOT_ENOUGH_PARTICIPANTS` | 422 | 주소 입력자 2명 미만 계산 | 안내 | ✗ |
| `COMPUTE_IN_PROGRESS` | 409 | 같은 방 계산 진행 중 | "계산 중이에요" + 결과 폴링 | 자동(폴링) |
| `RATE_LIMITED` | 429 | 요청 한도 초과 | 안내 (`Retry-After` 헤더) | `Retry-After` 후 |
| `TRANSIT_API_UNAVAILABLE` | 503 | 대중교통 API 장애·한도 소진 | "잠시 후 다시" | ✓ (최대 2회) |
| `INTERNAL_ERROR` | 500 | 예상 못한 결함 | 토스트 + traceId | ✓ (조회만) |

- 새 코드를 추가할 때는 이 표에 먼저 행을 추가하고, HTTP 상태·프론트 처리·재시도를 함께 정한다.

## 4. 예외 → 응답 변환 (백엔드)

| 예외 | 응답 |
|---|---|
| `BusinessException(ErrorCode)` | ErrorCode 의 status·code·기본 detail |
| `MethodArgumentNotValidException`, `ConstraintViolationException` | 400 `VALIDATION_FAILED` + `errors[]` |
| `DataIntegrityViolationException` (participant 닉네임 유니크) | 409 `NICKNAME_TAKEN` — **제약 이름으로 매핑**하되 응답에 제약 이름을 넣지 않는다 |
| `AuthenticationException` | 401 `UNAUTHENTICATED` |
| `AccessDeniedException` | 403 `FORBIDDEN` |
| 그 밖의 모든 예외 | 500 `INTERNAL_ERROR`, 로그에 ERROR + stack trace, 응답은 일반 문장 |
