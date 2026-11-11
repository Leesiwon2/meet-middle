# DB 규칙과 마이그레이션

> 상태: 초안 v0.1 / 2026-11-11
> 스키마 초안: [../prd/DESIGN.md](../prd/DESIGN.md) §8. 실제 스키마의 정본은 `backend/src/main/resources/db/migration/` 의 Flyway 파일이다.

## 1. 마이그레이션

- 파일: `V{번호}__{설명}.sql` (예: `V1__init.sql`, `V2__seed_hubs.sql`, `V3__add_room_memo.sql`). 번호는 정수 순번.
- **이미 `main` 에 들어간 V 파일은 절대 수정하지 않는다.** 바꿀 게 있으면 새 V 파일을 추가한다. (Flyway checksum 불일치로 기동 실패)
- 한 파일에는 하나의 목적. DDL 과 대량 데이터 변경을 섞지 않는다.
- 운영 데이터가 생긴 뒤에는 파괴적 변경(DROP COLUMN, 타입 축소)을 **2단계로** 한다: ① 코드에서 사용 중단 배포 → ② 다음 릴리스에서 DROP.
- 로컬 초기화: `docker compose -f infra/compose.yaml down -v` 후 재기동 (볼륨 삭제 = 데이터 전부 삭제).

## 2. 네이밍

| 대상 | 규칙 | 예 |
|---|---|---|
| 테이블 | 단수형 snake_case | `room`, `participant`, `hub` |
| 컬럼 | snake_case | `host_member_id`, `created_at` |
| PK | `id BIGSERIAL` (또는 `BIGINT GENERATED ALWAYS AS IDENTITY`) | |
| FK 컬럼 | `{참조테이블}_id` | `room_id` |
| 유니크 제약 | `uq_{테이블}_{컬럼들}` | `uq_room_nickname` → **오류 매핑에 쓰이므로 이름 변경 시 백엔드 매핑도 수정** |
| 체크 제약 | `ck_{테이블}_{뜻}` | `ck_participant_identity` |
| 인덱스 | `ix_{테이블}_{컬럼들}` | `ix_participant_room_id` |
| enum 성격 값 | `VARCHAR` + 대문자 코드 (DB enum 타입 쓰지 않음) | `status = 'OPEN'` |

## 3. 데이터 규칙

- 시간은 모두 `TIMESTAMPTZ`. `created_at`, `updated_at` 은 모든 업무 테이블에 둔다.
- 좌표는 `DOUBLE PRECISION` (위도 `lat`, 경도 `lng`). 공간 연산이 필요해지면 PostGIS 도입을 ADR 로 결정.
- 삭제
  - 방 만료 후 30일: participant 의 주소·좌표 컬럼 `NULL` 처리 (배치). 행 자체는 통계용으로 남김.
  - 회원 탈퇴: member 의 주소 즉시 삭제, 참여 기록은 닉네임만 남기고 `member_id` 연결 해제.
- 비밀번호는 BCrypt 해시만, 비회원 토큰은 SHA-256 해시만 저장.

## 4. 접근

- 원격(운영) DB 에 개발 PC 에서 직접 붙어 수정하지 않는다. 변경은 마이그레이션 파일로만.
- JPA N+1 주의: 목록 조회는 fetch join 또는 DTO 프로젝션. 통합 테스트에서 쿼리 수를 확인할 수 있게 `hibernate.generate_statistics` 를 test 프로필에서 켠다.
