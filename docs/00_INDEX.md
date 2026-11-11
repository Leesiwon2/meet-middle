# 문서 색인

> 상태: 활성 v1.0 / 2026-11-11
> 역할: `docs/` 진입점. 무엇을 할 때 어디를 보는지. 각 문서의 내용은 그 문서가 소유하고 여기서 복사하지 않는다.

## 1. 무엇을 할 때 어디를 보는가

| 하려는 일 | 문서 |
|---|---|
| 서비스가 뭘 하는지, 기능·화면·알고리즘·API·DB 초안 | [prd/DESIGN.md](prd/DESIGN.md) |
| 어떤 기술을 몇 버전으로 쓰는지 | [dev/TECH-STACK.md](dev/TECH-STACK.md) |
| 로컬에서 띄우기, 포트, 환경변수 | [dev/local-setup.md](dev/local-setup.md) |
| 지금 해야 할 기초 작업과 완료 조건 | [plan/PHASE-0-기초작업.md](plan/PHASE-0-기초작업.md) |
| 백엔드 코드를 쓴다 | [dev/BACKEND-GUIDE.md](dev/BACKEND-GUIDE.md) |
| 프론트 코드를 쓴다 | [dev/FRONTEND-GUIDE.md](dev/FRONTEND-GUIDE.md) |
| API 응답·오류 코드 | [dev/API-ERROR-CONTRACT.md](dev/API-ERROR-CONTRACT.md) |
| 테이블·마이그레이션 | [db/README.md](db/README.md) |
| 커밋·브랜치·PR, 문서 갱신 규칙 | [CONVENTION.md](CONVENTION.md) |
| 왜 그렇게 정했는지 | [decisions/adr/](decisions/adr/) — 새 결정은 [_TEMPLATE.md](decisions/adr/_TEMPLATE.md) |

## 2. 결정 기록 (ADR)

| 번호 | 제목 | 상태 |
|---|---|---|
| [ADR-001](decisions/adr/ADR-001-기술스택과버전.md) | 기술 스택과 기준 버전 | 문서 머리 참조 |
| [ADR-002](decisions/adr/ADR-002-대중교통API선정.md) | 대중교통 소요시간 API 선정 | 문서 머리 참조 |

> 상태는 각 문서 머리가 정본이다. 여기에 복사하지 않는다.

## 3. 폴더

| 경로 | 성격 |
|---|---|
| `prd/` | 요구사항·기획 |
| `dev/` | 개발 표준, 환경, 버전 |
| `db/` | DB 규칙 |
| `plan/` | 진행 중 계획 (완료되면 `archive/` 로) |
| `decisions/adr/` | 결정 기록 (폐기돼도 지우지 않고 상태만 바꾼다) |
