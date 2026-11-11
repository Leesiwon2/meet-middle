# 커밋 · 브랜치 · PR 관행 (CONVENTION)

> 상태: 초안 v0.1 / 2026-11-11
> 저장소: GitHub `Leesiwon2/meet-middle`. 자동 검사: `.githooks/commit-msg` (로컬), GitHub Actions (PR).

## 1. 커밋 메시지

형식: Conventional Commits — `type(scope): 제목`. type 은 영문 소문자, 제목·본문은 한국어.

```
feat(room): 방 생성 API 추가

방장은 회원만 가능. 방 코드는 혼동 문자 제외 6자리.
Refs #12
```

| type | 용도 |
|---|---|
| `feat` | 기능 추가 |
| `fix` | 결함 수리 (재현 테스트 동반. 못 두면 본문에 `시험-면제: <사유>`) |
| `docs` | 문서 |
| `test` | 테스트 추가·수리 |
| `refactor` | 동작 유지 구조 개선 |
| `perf` | 성능 |
| `style` | 포맷만 (동작 무관) |
| `build` | 빌드·의존성 (버전 변경 시 TECH-STACK.md 도 같은 커밋에서) |
| `ci` | CI 설정 |
| `chore` | 그 밖의 정리 |
| `revert` | 되돌림 |

- scope: `be`, `fe`, `db`, `infra`, `ci`, 또는 도메인(`room`, `participant`, `recommend`, `place`, `auth`). 여러 개면 쉼표, 자명하면 생략.
- 제목 72자 이내, 끝에 마침표 없음.
- 커밋 하나에 목적 하나. 포맷 변경과 기능 변경을 섞지 않는다.

## 2. 브랜치

- `main`: 항상 배포 가능 상태. **직접 push 금지**(브랜치 보호, P0-19).
- 작업 브랜치: `{type}/{짧은-설명}` — 예: `feat/room-create`, `fix/nickname-race`, `docs/phase0-plan`.
- 작업 브랜치는 짧게 유지(며칠 이내) 하고 병합 후 삭제.
- 강제 push 는 본인 작업 브랜치에서만, `main` 은 금지.

## 3. PR

- 모든 변경은 PR 로 `main` 에 들어간다. 병합 방식은 **Squash merge** (PR 제목이 커밋 제목이 되므로 PR 제목도 §1 형식).
- PR 본문은 `.github/pull_request_template.md` 를 따른다: 무엇을 / 왜 / 어떻게 검증했나 / 영향 범위(API·DB·화면) / 남은 일.
- 병합 조건: CI 전부 녹색 + 본인 셀프 리뷰 체크리스트 완료.
- API 계약이나 DB 스키마를 바꾸는 PR 은 [API-ERROR-CONTRACT.md](dev/API-ERROR-CONTRACT.md)·마이그레이션을 같은 PR 에 포함.

## 4. 문서

- 코드와 같은 PR 에서 문서를 고친다. 무엇을 바꾸면 어디를 고치는지:

| 바꾼 것 | 함께 고칠 문서 |
|---|---|
| 라이브러리·런타임 버전 | `docs/dev/TECH-STACK.md` |
| 오류 코드, 응답 형식 | `docs/dev/API-ERROR-CONTRACT.md` |
| 테이블·컬럼 | 마이그레이션 + (구조 변화가 크면) `docs/prd/DESIGN.md` §8 |
| 포트, 환경변수, 기동 절차 | `docs/dev/local-setup.md` |
| 패키지·폴더 구조 규칙 | `docs/dev/BACKEND-GUIDE.md` / `FRONTEND-GUIDE.md` |
| 되돌리기 비싼 설계 선택 | `docs/decisions/adr/` 에 ADR 추가 |

- 문서 머리에 `> 상태: (활성|초안) vX.Y / YYYY-MM-DD` 를 둔다.
- 같은 사실을 두 문서에 쓰지 않는다. 정본 하나를 두고 나머지는 링크.
