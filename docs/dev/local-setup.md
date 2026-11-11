# 로컬 실행 가이드

> 상태: 초안 v0.1 / 2026-11-11 — Phase 0 (P0-24) 에서 실제 클론으로 실증한 뒤 v1.0 으로 올린다.
> 버전 정본: [TECH-STACK.md](TECH-STACK.md)

## 1. 사전 준비

| 도구 | 필요 버전 | 확인 명령 |
|---|---|---|
| JDK | 21 (Temurin) | `"$JAVA_HOME/bin/java" -version` |
| Node.js | 24 LTS | `node -v` |
| pnpm | 12.18.0 (corepack) | `pnpm -v` |
| Docker Desktop | 27 이상 | `docker --version` |
| Git | 2.40 이상 | `git --version` |

### ⚠️ 주의
- 기본 `java` 가 21 이 아니면(여러 JDK 를 함께 쓰는 PC 등) Gradle 이 엉뚱한 JDK 로 돈다.
  - 해결: **이 프로젝트를 여는 터미널에서** `JAVA_HOME` 을 JDK 21 로 지정하거나, Gradle toolchain 자동 감지에 맡긴다(`build.gradle.kts` 에 toolchain 21 고정).
  - IntelliJ: Project SDK = 21, Gradle JVM = 21.
- Node 버전은 `.nvmrc` 를 따른다 (nvm-windows 또는 fnm 권장).
- pnpm 은 전역 버전과 무관하게 `corepack enable` 후 `packageManager` 필드 버전이 자동 사용된다.

## 2. 최초 1회

```bash
git clone https://github.com/Leesiwon2/meet-middle.git
cd meet-middle
git config core.hooksPath .githooks       # 커밋 규약 검사 배선 (클론마다 1회, 저장소에 커밋해도 자동 적용 안 됨)
git config commit.template .gitmessage    # 커밋 양식 자동 표시
cp .env.example .env                      # 키 값 채우기 (§4)
corepack enable
```

## 3. 기동 순서

```bash
# 1) DB · Redis
docker compose -f infra/compose.yaml --env-file .env up -d

# 2) 백엔드 (Flyway 가 기동 시 마이그레이션 적용)
cd backend && ./gradlew bootRun --args='--spring.profiles.active=local'
#    확인: curl http://localhost:18080/actuator/health  → {"status":"UP"}

# 3) 프론트 (API 코드 생성 → 개발 서버)
cd frontend && pnpm install --frozen-lockfile && pnpm gen:api && pnpm dev
#    확인: http://localhost:15173
```

> `pnpm gen:api` 를 건너뛰면 생성 코드가 없어 타입 검사·빌드가 실패한다. 생성물은 git 에 없다.

## 4. 환경변수와 비밀

`.env` 는 git 에 올리지 않는다(`.gitignore`). 저장소에는 키 이름만 있는 `.env.example` 만 둔다.

| 변수 | 필수 | 용도 | 없으면 |
|---|---|---|---|
| `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | ✓ | PostgreSQL | 기동 실패 |
| `REDIS_PORT` | ✓ | Redis | 기동 실패 |
| `JWT_SECRET` | ✓ | JWT 서명 (32바이트 이상 랜덤) | 기동 실패 (기본값 두지 않음) |
| `KAKAO_REST_API_KEY` | | 주소→좌표, 주변 장소 | `local` 프로필에서 Fake 사용 |
| `KAKAO_JS_KEY` | | 프론트 지도 (`VITE_KAKAO_JS_KEY`) | 지도 대신 목록만 표시 |
| `ODSAY_API_KEY` / `TMAP_APP_KEY` | | 대중교통 소요시간 (ADR-002 확정 후 하나) | Fake(직선거리 추정) 사용 |

- 비밀값을 대화창, 이슈, PR, 로그에 붙여넣지 않는다.
- 키가 노출되면 즉시 콘솔에서 재발급하고 `.env` 를 교체한다.

## 5. 접속 요약

| 대상 | 주소 |
|---|---|
| 프론트 | http://localhost:15173 |
| 백엔드 API | http://localhost:18080/api |
| API 문서 (Swagger UI) | http://localhost:18080/swagger-ui.html (local 프로필에서만) |
| Health | http://localhost:18080/actuator/health |
| PostgreSQL | localhost:15432 |
| Redis | localhost:16379 |

## 6. 자주 막히는 곳

| 증상 | 원인 | 조치 |
|---|---|---|
| `Unsupported class file major version` | JDK 1.8/17 로 Gradle 실행 | §1 JDK 21 설정 |
| 포트 5432/8080 충돌 | 기본 포트를 쓰는 다른 서비스와 겹침 | 이 프로젝트는 15432/18080 이다. `.env` 확인 |
| 프론트 타입 오류 `Cannot find module '@/api/generated'` | 생성 코드 없음 | 백엔드 기동 또는 `./gradlew generateOpenApiDocs` 후 `pnpm gen:api` |
| POST 가 403 | CSRF 토큰 헤더 누락 | 공통 fetch 를 거치지 않은 호출. [FRONTEND-GUIDE](FRONTEND-GUIDE.md) §4 |
