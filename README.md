# meet-middle (가칭: 중간지점)

친구들끼리 "어디서 만나?" 를 끝내는 서비스.
링크를 공유하면 각자 집·회사 주소를 입력하고, **대중교통 기준으로 가장 공평한 만남 장소**와 주변 맛집·술집을 추천받는다.

- 회원 로그인 또는 **비회원(닉네임)** 으로 링크 참여 — 닉네임 중복은 방 안에서만 검사
- 참여자마다 이번 모임 **출발지(집·회사·기타)** 를 골라 계산하고, **퇴근 후(회사 출발) / 주말(집 출발)** 과 비교 추천
- 추천 장소마다 참여자 각자의 출발지에서 걸리는 시간 표시

## 스택

Java 21 · Spring Boot 4.1 · PostgreSQL 18 · Redis 8 / React 19 · TypeScript 6 · Vite 8 — 상세는 [docs/dev/TECH-STACK.md](docs/dev/TECH-STACK.md)

## 문서

| | |
|---|---|
| 문서 색인 | [docs/00_INDEX.md](docs/00_INDEX.md) |
| 기획·설계 | [docs/prd/DESIGN.md](docs/prd/DESIGN.md) |
| 기초 작업 계획 | [docs/plan/PHASE-0-기초작업.md](docs/plan/PHASE-0-기초작업.md) |
| 로컬 실행 | [docs/dev/local-setup.md](docs/dev/local-setup.md) |
| 개발 규약 | [docs/CONVENTION.md](docs/CONVENTION.md) |

## 상태

Phase 0 (기초 작업) 준비 중 — 아직 실행 가능한 코드는 없다.
