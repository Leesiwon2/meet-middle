# CLAUDE.md (meet-middle 진입점)

> 상태: 활성 v1.0 / 2026-11-11
> 역할: 이 저장소에서 작업할 때 가장 먼저 읽는 자리. **규칙은 여기서 만들지 않고 정본 문서로 연결한다.**

## 0. 무엇을 할 때 어디를 보는가

| 하려는 일 | 정본 |
|---|---|
| **세션을 새로 시작한다 (지금 상태·다음 할 일)** | `HANDOVER.md` |
| 문서를 찾는다 | `docs/00_INDEX.md` |
| 요구사항·화면·알고리즘 | `docs/prd/DESIGN.md` |
| 버전을 확인하거나 의존성을 추가한다 | `docs/dev/TECH-STACK.md` |
| 지금 할 일 | `docs/plan/PHASE-0-기초작업.md` |
| 백엔드 코드 | `docs/dev/BACKEND-GUIDE.md` |
| 프론트 코드 | `docs/dev/FRONTEND-GUIDE.md` |
| API·오류 계약 | `docs/dev/API-ERROR-CONTRACT.md` |
| DB·마이그레이션 | `docs/db/README.md` |
| 로컬 기동 | `docs/dev/local-setup.md` |
| 커밋·브랜치·PR | `docs/CONVENTION.md` |
| 결정이 필요하다 | `docs/decisions/adr/_TEMPLATE.md` |

## 1. 틀리면 비싼 것

- **JDK 21.** Gradle 은 toolchain 21 로 돈다. 기본 `java` 가 21 이 아니면 `JAVA_HOME` 을 21 로 지정한다 (`docs/dev/local-setup.md` §1).
- **포트는 1xxxx 대역** (PG 15432 · Redis 16379 · 백엔드 18080 · 프론트 15173). 기본 포트와 충돌하지 않게 앞에 1을 붙였다. 포트를 바꾸면 CORS 허용 출처와 Vite 프록시도 함께 바꾼다.
- **프론트는 `pnpm gen:api`(orval) 를 먼저 돌려야 빌드된다.** 생성물은 git 에 없다.
- **적용된 Flyway V 파일은 수정하지 않는다.** 새 파일을 추가한다.
- **커밋 규약 훅은 클론마다 1회 배선**: `git config core.hooksPath .githooks`.
- **Git 계정**: 이 저장소는 개인 계정 `Leesiwon2` 로 커밋·push 한다(로컬 `user.name`/`user.email` 설정, remote URL 에 `Leesiwon2@`). 전역 설정은 건드리지 않는다.

## 2. 프로젝트 개요

- 서비스: 링크를 공유받은 친구들이 집·회사 주소를 입력하면 대중교통 기준으로 가장 공평한 만남 장소와 주변 맛집·술집을 추천.
- 스택: Java 21 · Spring Boot 4.1 · JPA · PostgreSQL 18 · Redis 8 / React 19 · TypeScript 6 strict · Vite 8 · TanStack Query · Tailwind 4 · pnpm. 정확한 버전은 TECH-STACK.
- 단계: **Phase 0 (기초 작업)** 진행 전.

## 3. 절대 규칙

| 금지 | 대신 |
|---|---|
| 엔티티 직접 반환 | 응답 DTO(record) |
| 다른 참여자의 정확한 주소·좌표를 응답·로그에 | `region`(동 단위)만 |
| 비밀값(API 키, JWT 시크릿) 하드코딩·커밋 | `.env` + 환경변수 |
| 프론트 `any`, 컴포넌트 안 직접 fetch | 좁은 타입, orval 생성 훅 |
| ProblemDetail `detail` 문자열로 분기 | `code` 로 분기 |
| `main` 직접 push | 작업 브랜치 → PR |
| 버전을 TECH-STACK 밖 문서에 복사 | TECH-STACK 링크 |

## 4. 작업 방식

- 작업 브랜치를 만들어 PR 로 `main` 에 통합한다 (`docs/CONVENTION.md`).
- 문서는 같은 작업에서 갱신한다 (CONVENTION §4 의 매핑).
- 결정을 임의로 하지 않는다. 미결이면 ADR 을 Proposed 로 올리고 묻는다.
- 완료 보고에는 실제로 실행한 검증과 결과를 적는다. 실행하지 않은 검증은 "미실행" 으로 적는다.
- 모호하면 묻는다.

## 5. 폴더

| 경로 | 내용 |
|---|---|
| `backend/` | Spring Boot (Phase 0 P0-04 에서 생성) |
| `frontend/` | React (P0-13 에서 생성) |
| `infra/` | Docker Compose, 시드 데이터 |
| `scripts/` | 보조 스크립트, PoC |
| `docs/` | 문서 전체. 진입은 `docs/00_INDEX.md` |
