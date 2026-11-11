# Phase 0 — 기초 작업 계획

> 상태: 초안 v0.1 / 2026-11-11
> 역할: 기능 개발(M1~) 전에 갖출 **저장소 골격, 공통 기반, 품질 게이트, 외부 API 검증**의 작업 목록과 완료 조건.
> 완료 판정: 모든 항목의 "완료 조건"을 **직접 실행해서** 확인한다. 문서나 진술로 대신하지 않는다.
> 관련: 요구사항 [prd/DESIGN.md](../prd/DESIGN.md) · 버전 [dev/TECH-STACK.md](../dev/TECH-STACK.md) · 규칙 [dev/BACKEND-GUIDE.md](../dev/BACKEND-GUIDE.md), [dev/FRONTEND-GUIDE.md](../dev/FRONTEND-GUIDE.md)

## 0. Phase 0 이 끝나면 되는 것

1. 새로 클론한 PC에서 `docs/dev/local-setup.md` 대로만 따라 하면 **DB·백엔드·프론트가 뜬다.**
2. 프론트 화면에서 백엔드 API를 호출하고, **오류가 공통 계약대로** 표시된다.
3. PR 을 올리면 **CI가 빌드·테스트·린트·비밀 탐지**를 돌리고, 실패하면 병합할 수 없다.
4. 대중교통 API 를 **실제로 호출해 본 결과**로 ODsay/TMAP 중 하나가 확정된다(ADR-002).
5. 후보 역(hub) 80개 이상이 마이그레이션으로 DB에 들어간다.

## 1. 작업 목록

순서는 의존 관계 순이다. `선행` 열의 항목이 끝나야 시작할 수 있다. 같은 묶음 안에서는 병렬 가능.

### 묶음 A — 저장소 골격

| ID | 작업 | 선행 | 완료 조건 |
|---|---|---|---|
| **P0-01** | 모노레포 폴더 생성: `backend/`, `frontend/`, `infra/`, `scripts/`, `.github/`. 루트에 `.editorconfig`(UTF-8, LF, 들여쓰기 규칙), `.gitattributes`(`* text=auto eol=lf`, `*.bat eol=crlf`), `.gitignore` 보강, `.nvmrc`(24) | — | `git ls-files --eol` 에서 텍스트 파일이 전부 `i/lf` |
| **P0-02** | 로컬 인프라: `infra/compose.yaml` (PostgreSQL 18, Redis 8.8), 포트·계정은 루트 `.env.example` → `.env` 복사 방식. **1xxxx 대역 포트**(§3) | P0-01 | `docker compose -f infra/compose.yaml up -d` 후 `pg_isready`·`redis-cli ping` 성공 |
| **P0-03** | 커밋 규약 배선: `.gitmessage`, `.githooks/commit-msg`(type 검사, bash), `.githooks/pre-commit`(gitleaks 있으면 실행). 클론당 `git config core.hooksPath .githooks` 를 local-setup 에 명시 | P0-01 | 규약 위반 메시지(`update stuff`) 커밋이 거부되고, `docs: 문서 수정` 은 통과 |

### 묶음 B — 백엔드 기반

| ID | 작업 | 선행 | 완료 조건 |
|---|---|---|---|
| **P0-04** | Spring Boot 4.1.2 프로젝트 생성: Gradle Kotlin DSL, Wrapper 9.9.1, toolchain 21, 의존성(TECH-STACK §3), 패키지 `com.meetmiddle`, 프로필 `local`/`test`, 가상 스레드 on, Actuator health 노출 | P0-02 | `./gradlew build` 성공 · `./gradlew bootRun` 후 `GET /actuator/health` → `UP`(DB·Redis 포함) |
| **P0-05** | Flyway: `V1__init.sql`(DESIGN §8 DDL: member, room, participant, hub, recommendation), 네이밍 규칙은 [db/README.md](../db/README.md) | P0-04 | 빈 DB에서 기동 시 V1 적용 · `flyway_schema_history` 1행 |
| **P0-06** | 공통 오류 계약: `ErrorCode` enum, `BusinessException`, `@RestControllerAdvice` → ProblemDetail(RFC 9457) + `code` + `traceId`, Validation 오류 → `errors[]`. 상세는 [API-ERROR-CONTRACT.md](../dev/API-ERROR-CONTRACT.md) | P0-04 | MockMvc 테스트: 존재하지 않는 방 → 404 `ROOM_NOT_FOUND`, 잘못된 body → 400 `VALIDATION_FAILED` + 필드 오류, 예상 못한 예외 → 500 에 stack trace 미노출 |
| **P0-07** | 요청 추적·로깅: `traceId` 필터(MDC, 응답 헤더 `X-Trace-Id`), 로그 패턴, 개인정보(주소·좌표·토큰) 로그 금지 규칙. `Clock` 빈 주입(시간 의존 테스트용) | P0-04 | 모든 응답에 `X-Trace-Id` · 오류 본문 `traceId` 와 로그가 일치 |
| **P0-08** | 보안 골격: `SecurityFilterChain`(경로별 공개/회원/참여자), JWT 쿠키 발급·검증 필터, 비회원 참여 토큰 필터(`pt_{code}`), CORS(로컬 프론트 출처만), CSRF(`CookieCsrfTokenRepository` + SPA 헤더 `X-XSRF-TOKEN`), BCrypt. 실제 회원가입 API 는 M1 | P0-06 | 테스트: 보호 경로 미인증 → 401 ProblemDetail · 위조 JWT → 401 · CSRF 토큰 없는 POST → 403 |
| **P0-09** | 외부 API 클라이언트 골격: `KakaoLocalClient`, `TransitClient` 인터페이스 + `Fake*` 구현(직선거리 × 계수), `RestClient` 공통 설정(타임아웃 3초, 재시도 1회), 키는 환경변수만([local-setup §4](../dev/local-setup.md#4-환경변수와-비밀)) | P0-04 | `local` 프로필에서 키 없이도 Fake 로 기동 · 클라이언트 테스트(Stub 서버) 통과 |
| **P0-10** | 아키텍처 규칙 테스트: ArchUnit — 도메인 패키지 간 순환 금지, `controller → service → repository` 방향, `external` 은 도메인 서비스에서만 사용, 엔티티를 Controller 가 반환 금지 | P0-04 | 규칙 위반 샘플 코드로 테스트가 실패하는 것 확인 후 샘플 제거 |
| **P0-11** | 통합 테스트 기반: Testcontainers(PostgreSQL 18 이미지 = 로컬과 동일), `@ServiceConnection`, 공통 베이스 클래스 `AbstractIntegrationTest` | P0-05 | `./gradlew test` 에서 컨테이너 기동 → V1 적용 → 샘플 저장소 테스트 통과 |
| **P0-12** | OpenAPI 노출: springdoc, `/v3/api-docs` 를 빌드 시 `backend/build/openapi.json` 으로 내보내는 Gradle 작업 | P0-06 | `./gradlew generateOpenApiDocs`(또는 동등 작업)로 파일 생성 |

### 묶음 C — 프론트 기반

| ID | 작업 | 선행 | 완료 조건 |
|---|---|---|---|
| **P0-13** | Vite 8 + React 19 + TS 6 strict 프로젝트, pnpm 12(`packageManager`), 경로 별칭 `@/`, Tailwind 4, ESLint 10 flat + typescript-eslint + Prettier. 폴더 구조는 [FRONTEND-GUIDE](../dev/FRONTEND-GUIDE.md) §2 | P0-01 | `pnpm install --frozen-lockfile && pnpm lint && pnpm typecheck && pnpm build` 성공 |
| **P0-14** | API 계층: orval 설정(입력 = P0-12 의 openapi.json, 출력 = `src/api/generated/`, **생성물은 git 제외**), 공통 fetch(`credentials: 'include'`, CSRF 헤더, ProblemDetail 파싱 → `ApiError`), TanStack Query 기본값(재시도 정책: 4xx 재시도 안 함) | P0-12, P0-13 | `pnpm gen:api` 후 health 호출 훅이 생성되고 타입 검사 통과 |
| **P0-15** | 앱 셸: Router(DESIGN §7.1 라우트 자리만), 레이아웃(모바일 우선), 공통 오류 화면·토스트, 404 화면. 화면 문구는 `src/shared/messages.ts` 한 곳(다국어는 후속) | P0-14 | 로컬에서 `/` 접속 → 백엔드 health 상태 표시 · 백엔드 중지 시 오류 화면 표시 |
| **P0-16** | 프론트 테스트 기반: Vitest + Testing Library + MSW(핸들러 = orval mock 생성 활용), Playwright 스모크 1건(`/` 렌더) | P0-15 | `pnpm test` · `pnpm e2e` 통과 |

### 묶음 D — 품질 게이트 · CI

| ID | 작업 | 선행 | 완료 조건 |
|---|---|---|---|
| **P0-17** | 포맷: Spotless(google-java-format) `spotlessCheck` 를 `build` 에 연결 · 프론트 `prettier --check` | P0-04, P0-13 | 포맷 깨진 파일로 빌드 실패 확인 |
| **P0-18** | GitHub Actions `ci.yml`: ① backend `./gradlew build`(테스트·Spotless·ArchUnit 포함) ② frontend `lint`/`typecheck`/`test`/`build` (OpenAPI 생성 → orval 순서) ③ gitleaks ④ 커밋 메시지 규약 검사(PR 범위) | P0-11, P0-16, P0-17 | PR 에서 4개 잡이 모두 녹색 |
| **P0-19** | 저장소 보호: `main` 브랜치 보호(PR 필수, CI 통과 필수, force push 금지), PR 템플릿 `.github/pull_request_template.md` | P0-18 | `main` 직접 push 가 거부됨 |

### 묶음 E — 도메인 준비 · 외부 API 검증

| ID | 작업 | 선행 | 완료 조건 |
|---|---|---|---|
| **P0-20** | 외부 API 키 발급: 카카오 개발자(REST 키, JS 키 + 도메인 `localhost`), ODsay LAB, TMAP. 키는 `.env` 에만 | — | 각 API 1회 호출 성공 (curl) |
| **P0-21** | 대중교통 API PoC: 같은 출발지 10곳 × 도착 hub 10곳을 ODsay·TMAP 으로 조회해 **응답 시간, 실패율, 소요시간 차이, 무료 한도·요금·상업 이용 조건** 비교. 스크립트는 `scripts/poc/` | P0-20 | 비교표를 ADR-002 에 기입하고 Accepted 로 변경 |
| **P0-22** | hub 시드 데이터: 수도권 약속 장소 역 80개 이상(이름, 좌표, 노선, 지역, 가중치) → `infra/seed/hubs.csv` + `V2__seed_hubs.sql`. 좌표는 카카오 로컬 API 로 일괄 조회 | P0-05, P0-20 | `SELECT count(*) FROM hub WHERE active` ≥ 80 · 좌표 이상치 0건(수도권 경계 밖) |
| **P0-23** | 추천 알고리즘 오프라인 검증: P0-21 결과로 DESIGN §5.3 점수식을 실제 친구 그룹 예시 3건에 적용해 결과가 상식적인지 확인 | P0-21, P0-22 | 예시 3건 결과와 가중치 조정 메모를 DESIGN §5 에 추가 |

### 묶음 F — 문서 마감

| ID | 작업 | 선행 | 완료 조건 |
|---|---|---|---|
| **P0-24** | local-setup 실증: 새 폴더에 클론해서 문서만 보고 기동. 막힌 곳은 문서 수정 | 전부 | 새 클론에서 30분 이내 기동 |
| **P0-25** | CLAUDE.md "틀리면 비싼 것" 갱신, TECH-STACK 실제 빌드 파일과 대조 | 전부 | 표와 빌드 파일 버전 불일치 0건 |

## 2. 진행 순서 (권장)

```
주 1 : P0-01 → P0-02 → P0-03 │ P0-20(키 발급, 승인 대기 시간 있음 → 먼저 신청)
주 1~2: P0-04 → P0-05, P0-06 → P0-07, P0-08, P0-09, P0-10, P0-11, P0-12
주 2 : P0-13 → P0-14 → P0-15 → P0-16
주 2~3: P0-17 → P0-18 → P0-19 │ P0-21 → P0-22 → P0-23
주 3 : P0-24, P0-25  → Phase 0 종료 → M1(회원/방/참여) 착수
```

## 3. 로컬 포트

기본 포트(5432·6379·8080·5173)와 충돌하지 않게 **앞에 1을 붙인 대역**을 쓴다.

| 서비스 | 포트 |
|---|---|
| PostgreSQL | 15432 |
| Redis | 16379 |
| 백엔드 | 18080 |
| 프론트(Vite dev) | 15173 |
| 프론트(preview) | 14173 |

포트는 루트 `.env` 한 곳에서 나온다. 바꾸면 백엔드 CORS 허용 출처와 Vite 프록시를 함께 바꾼다.

## 4. Phase 0 에서 하지 않는 것

- 회원가입·방·참여·추천 **기능 API** (M1~M2)
- 실제 화면 디자인 (M3)
- 배포 환경 구성 (Phase 1 이후, 별도 ADR)
- 카카오 소셜 로그인 (후속)

## 5. 진행 현황

| ID | 상태 | 날짜 | PR |
|---|---|---|---|
| P0-01 ~ P0-25 | 대기 | | |
