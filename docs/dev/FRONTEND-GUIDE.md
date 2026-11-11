# 프론트엔드 구조와 코딩 규칙 (FRONTEND-GUIDE)

> 상태: 초안 v0.1 / 2026-11-11
> 대상: `frontend/` 아래 모든 코드. 버전은 [TECH-STACK.md](TECH-STACK.md), 오류 계약은 [API-ERROR-CONTRACT.md](API-ERROR-CONTRACT.md).

## 1. 원칙

1. **모바일 우선.** 대부분 단톡방 링크로 휴대폰에서 들어온다. 기준 폭 360px, 데스크톱은 가운데 정렬 최대 480px 부터 시작.
2. **서버 상태는 TanStack Query, 클라이언트 상태는 최소한으로.** 서버에서 온 데이터를 Zustand 에 복사하지 않는다.
3. **API 타입은 손으로 쓰지 않는다.** 백엔드 OpenAPI → orval 생성물만 쓴다.
4. **외부 라이브러리(카카오맵 등)는 래퍼로 감싼다.** 화면은 래퍼만 import 한다.

## 2. 폴더 구조

```
frontend/
 ├─ package.json · pnpm-lock.yaml · vite.config.ts · tsconfig.json · eslint.config.js · orval.config.ts
 ├─ e2e/                         Playwright
 └─ src/
    ├─ main.tsx · App.tsx
    ├─ app/                      라우터, Provider(QueryClient), 레이아웃
    ├─ api/
    │   ├─ generated/            orval 생성물 (git 제외, 직접 수정 금지)
    │   ├─ http.ts               공통 fetch (credentials, CSRF, ProblemDetail → ApiError)
    │   └─ errors.ts             ApiError 타입, code → 사용자 문구 매핑
    ├─ features/                 기능 단위 (화면 + 그 화면 전용 컴포넌트/훅)
    │   ├─ auth/                 로그인, 회원가입
    │   ├─ room/                 방 생성(S2), 공유(S3), 입장(S4), 대기실(S6)
    │   ├─ participant/          닉네임, 주소 입력(S5)
    │   ├─ recommend/            결과(S7)
    │   └─ place/                주변 추천(S8)
    ├─ shared/
    │   ├─ ui/                   Button, Input, Toast, Dialog 등 공통 UI
    │   ├─ lib/kakao-map/        카카오맵 SDK 래퍼
    │   ├─ hooks/                범용 훅
    │   └─ messages.ts           화면 문구 모음 (하드코딩 금지 → 여기서 import)
    └─ test/                     MSW 핸들러, 테스트 유틸
```

- `features/A` 가 `features/B` 내부 파일을 import 하지 않는다. 공유가 필요하면 `shared/` 로 올린다.
- 화면 컴포넌트 파일 하나가 200줄을 넘으면 하위 컴포넌트·훅으로 나눈다.

## 3. 절대 규칙

| 금지 | 대신 |
|---|---|
| `any`, `as unknown as X`, `@ts-ignore` | 좁은 타입, 타입 가드, zod 파싱 |
| 컴포넌트 안 `fetch`/`useEffect` 로 데이터 요청 | orval 생성 훅(TanStack Query) |
| `api/generated/` 직접 수정 | 백엔드 OpenAPI 수정 후 재생성 |
| ProblemDetail 의 `detail` 문자열로 분기 | `code` 로 분기 |
| `div onClick` 으로 이동·행위 | `<Link>`, `<button>` |
| 브라우저 `alert`/`confirm` | 공통 Dialog |
| 다른 참여자의 정확한 주소 표시 | `region`(동 단위)만 — API 도 그것만 준다 |
| 비밀 키를 코드에 | `VITE_` 환경변수 (공개되어도 되는 JS 키만. REST 키는 프론트에 두지 않는다) |

## 4. API 호출

- 모든 요청은 `api/http.ts` 의 공통 함수를 거친다 (orval `mutator` 로 지정).
  - `credentials: 'include'` (JWT·참여 토큰 쿠키)
  - 변경 요청(POST/PUT/PATCH/DELETE)에 `X-XSRF-TOKEN` 헤더 (쿠키 `XSRF-TOKEN` 값)
  - 응답이 `application/problem+json` 이면 `ApiError { status, code, detail, errors, traceId }` 로 throw
- TanStack Query 기본값
  - `retry`: 네트워크 오류·5xx·503 만 최대 2회. **4xx 는 재시도하지 않는다.**
  - 대기실 참여자 목록: `refetchInterval: 3000`, 탭이 백그라운드면 중지(`refetchIntervalInBackground: false`).
- 오류 표시
  - 필드 오류(400 `VALIDATION_FAILED`, 409 `NICKNAME_TAKEN`) → 해당 입력칸 아래
  - 권한·없음(401/403/404/410) → 전용 화면 (예: "만료된 방이에요")
  - 그 밖 → 토스트 + `traceId` 일부 표시 (문의용)

## 5. 스타일

- Tailwind 4 유틸리티 + `@theme` 디자인 토큰(색, 간격, 반경)을 `src/index.css` 한 곳에 정의.
- 다크 모드는 후속. 색은 토큰 이름으로만 쓴다(`bg-surface`, `text-muted`) — 나중에 다크 모드 추가 시 토큰만 바꾼다.
- 터치 영역 최소 44×44px, 포커스 표시 제거 금지.

## 6. 테스트

| 종류 | 도구 | 대상 |
|---|---|---|
| 단위 | Vitest | 순수 함수 (닉네임 형식 검사, 시간 포맷) |
| 컴포넌트 | Testing Library + MSW | 화면별 정상·오류 흐름 (예: 닉네임 중복 → 입력칸 오류 표시) |
| E2E | Playwright | 핵심 시나리오: 방 생성 → 비회원 입장 → 주소 입력 → 결과 (M4 부터) |

- 테스트는 사용자 관점 쿼리(`getByRole`, `getByLabelText`) 를 쓴다. `data-testid` 는 최후 수단.
