# 기술 스택과 버전 (TECH-STACK)

> 상태: 활성 v1.0 / 2026-11-11
> 역할: 사용하는 기술과 **고정 버전**의 정본. 다른 문서는 버전을 복사하지 않고 여기를 가리킨다.
> 근거: 2026-11-11 에 각 레지스트리(Maven Central, npm, Gradle, Node.js 배포 목록, Docker Hub, GitHub Releases)에서 최신 안정판을 직접 조회했다. 선택 이유는 [ADR-001](../decisions/adr/ADR-001-기술스택과버전.md).

## 1. 고정 원칙

1. **버전은 이 표와 빌드 파일 두 곳에만 있다.** 빌드 파일(`build.gradle.kts`, `package.json`, `compose.yaml`)을 바꾸면 이 표를 같은 커밋에서 고친다.
2. **Spring Boot BOM 이 관리하는 라이브러리는 버전을 직접 적지 않는다.** (Spring Framework, Spring Security, Hibernate, Flyway, PostgreSQL JDBC, Jackson, Testcontainers, JUnit 등) 표에 "BOM" 으로 표기한다.
3. **프론트는 정확한 버전으로 고정한다**(`^`, `~` 금지, `pnpm-lock.yaml` 커밋). 업그레이드는 의도한 커밋에서만 일어나게 한다.
4. **메이저 업그레이드는 ADR 로 결정한다.** 마이너·패치는 PR 한 건으로 올리고 CI 통과를 확인한다.
5. 점검 주기: 월 1회 패치 버전 확인 (보안 공지는 즉시).
6. **지원 종료일을 추적한다.** 확인: `curl -s https://endoflife.date/api/spring-boot.json` (Node 는 `nodejs.json`, PostgreSQL 은 `postgresql.json`).

| 항목 | 오픈소스 지원 종료 | 조치 기한 |
|---|---|---|
| Spring Boot 4.1 | 2027-07-31 | 2027-05 까지 다음 마이너로 |
| (참고) Spring Boot 3.5 | **2026-06-30 종료됨** | 사용하지 않음 |

## 2. 런타임 · 빌드 도구

| 항목 | 버전 | 비고 |
|---|---|---|
| JDK | **21 LTS** (Eclipse Temurin) | Gradle toolchain 으로 고정. 기본 `java` 가 21 이 아니면 → [local-setup](local-setup.md) §1 |
| Gradle | **9.9.1** (Wrapper) | `gradlew` 만 사용. 로컬 설치 Gradle 사용 금지 |
| Node.js | **24 LTS** (24.22.x, "Krypton") | `.nvmrc` 로 고정 |
| pnpm | **12.18.0** | `package.json` 의 `packageManager` 필드로 고정, corepack 사용 |
| Docker / Compose | 27.x 이상 | 로컬 PostgreSQL·Redis 용 |

## 3. 백엔드

| 항목 | 버전 | 용도 |
|---|---|---|
| Spring Boot | **4.1.2** | 애플리케이션 프레임워크 (Spring Framework 7 계열). ⚠️ 4.1 오픈소스 지원 종료 **2027-07-31** → 그 전에 다음 마이너로 업그레이드 (ADR-001) |
| Spring Web MVC | BOM | REST API (가상 스레드 사용: `spring.threads.virtual.enabled=true`) |
| Spring Security | BOM | 회원 JWT 쿠키, 비회원 참여 토큰, CSRF |
| Spring Data JPA / Hibernate | BOM | 영속성. 단순 CRUD 도메인이라 JPA 채택 (ADR-001 §5) |
| Spring Data Redis (Lettuce) | BOM | 소요시간 캐시, 계산 락, rate limit |
| Spring Validation | BOM | 요청 DTO 검증 |
| Spring Boot Actuator | BOM | `/actuator/health` |
| Flyway (+ flyway-database-postgresql) | BOM | 스키마 마이그레이션 |
| PostgreSQL JDBC | BOM | |
| springdoc-openapi-starter-webmvc-ui | **3.2.0** | OpenAPI 3.1 문서 생성 → 프론트 orval 입력 |
| jjwt (api / impl / jackson) | **0.13.0** | JWT 서명·검증 |
| **테스트** | | |
| JUnit 5 · AssertJ · Mockito | BOM | 단위 테스트 |
| Testcontainers (postgresql) | BOM (2.0.x 계열) | 통합 테스트는 실제 PostgreSQL 컨테이너로 |
| ArchUnit (archunit-junit5) | **1.5.1** | 패키지 의존 방향 규칙 검사 |
| WireMock 또는 MockRestServiceServer | P0-09 에서 결정 | 외부 API 클라이언트 테스트 |
| **품질** | | |
| Spotless Gradle Plugin | **8.11.0** | 포맷 검사·적용 |
| google-java-format | **2.0.0** | Spotless 포맷터 |

- **쓰지 않는 것**: Lombok(Java record 와 IDE 생성으로 대체), QueryDSL(필요 시 ADR), WebFlux(MVC + 가상 스레드로 충분).

## 4. 프론트엔드

| 항목 | 버전 | 용도 |
|---|---|---|
| React / React DOM | **19.3.1** | UI |
| Vite | **8.3.8** | 개발 서버·빌드 (Node ^20.19 또는 >=22.12 요구) |
| @vitejs/plugin-react | **6.3.0** | |
| TypeScript | **6.0.3** | `strict: true`. ⚠️ **7.x 사용 금지**: typescript-eslint 8.72.2 의 지원 범위가 `>=4.8.4 <6.1.0` (2026-11-11 확인). 지원 범위가 7을 포함하면 ADR 로 올린다 |
| React Router | **8.5.1** | 라우팅 (SPA, 데이터 라우터 사용) |
| TanStack Query | **5.107.1** | 서버 상태, 폴링(대기실 3초) |
| Zustand | **5.1.0** | 가벼운 클라이언트 전역 상태 (로그인 사용자 등) |
| Tailwind CSS / @tailwindcss/vite | **4.3.5** | 스타일 (모바일 우선) |
| react-hook-form | **7.91.0** | 폼 |
| zod | **4.6.7** | 폼 검증 스키마 |
| orval | **8.47.0** | OpenAPI → 타입 + TanStack Query 훅 생성 |
| 카카오맵 JavaScript SDK | 스크립트 로드 (버전 없음) | 지도 표시. 래퍼 컴포넌트로만 사용 |
| **테스트** | | |
| Vitest | **5.1.0** | 단위·컴포넌트 테스트 |
| @testing-library/react | **16.3.3** | 컴포넌트 테스트 |
| MSW | **3.0.5** | API 목킹 (테스트·로컬 개발) |
| Playwright (@playwright/test) | **1.65.0** | E2E 스모크 |
| **품질** | | |
| ESLint | **10.14.0** | 린트 (flat config) |
| typescript-eslint | **8.72.2** | TS 린트 규칙 |
| Prettier | **3.9.10** | 포맷 |

## 5. 인프라 · 외부 서비스

| 항목 | 버전 / 선택 | 비고 |
|---|---|---|
| PostgreSQL | **18** (`postgres:18.6-alpine`) | 로컬·CI 동일 이미지 |
| Redis | **8.8** (`redis:8.8.4-alpine`) | |
| CI | GitHub Actions | `actions/checkout@v7`, `actions/setup-java@v6`, `actions/setup-node@v7`, `pnpm/action-setup@v6`, `gradle/actions@v6` |
| 비밀 탐지 | gitleaks **8.30.1** | CI + (선택) 로컬 pre-commit |
| 주소→좌표, 주변 장소 | 카카오 로컬 REST API | |
| 대중교통 소요시간 | ODsay LAB (1순위) / TMAP (대안) | **미확정**: [ADR-002](../decisions/adr/ADR-002-대중교통API선정.md), P0-14 PoC 후 확정 |
| 배포 대상 | 미정 | Phase 1 이후 결정 (후보: 단일 VM + Docker Compose, 또는 관리형 PaaS) |

## 6. 버전 확인 명령 (갱신 시 재사용)

```bash
# Maven Central 최신 (예: Spring Boot)
curl -s https://repo1.maven.org/maven2/org/springframework/boot/spring-boot/maven-metadata.xml | grep -o '<release>[^<]*'
# npm 최신 (예: react)
curl -s https://registry.npmjs.org/react/latest | grep -o '"version":"[^"]*"'
# Gradle 최신
curl -s https://services.gradle.org/versions/current | grep '"version"'
# Node LTS 목록
curl -s https://nodejs.org/dist/index.json | grep -o '"version":"[^"]*"[^}]*"lts":"[^"]*"' | head -3
```

## 7. 변경 이력

| 날짜 | 변경 | 근거 |
|---|---|---|
| 2026-11-11 | 최초 고정 | ADR-001 |
| 2026-11-11 | 지원 종료일 추적 표 추가 (Spring Boot 3.5 종료 확인, 4.1 종료일 명시) | ADR-001 |
