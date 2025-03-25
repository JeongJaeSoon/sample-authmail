# 임시 유저 인증 시스템 설계서

## 1. 개요

### 1.1 시스템 목적

- Rails 백엔드와 React 프론트엔드 기반 임시 유저 인증 시스템 구현
- 회사(Company)와 거래처(Partner) 간 데이터 분리가 필요한 B2B 환경 대응
- 메일 주소 기반 임시 인증 제공

### 1.2 주요 기능

- 이메일 주소 기반 임시 사용자 인증
- 임시 비밀번호 생성 및 관리
- 세션 기반 인증 및 상태 관리
- 세션 하이재킹 방지
- 동일 사용자의 중복 로그인 관리

### 1.3 시스템 구성

- **백엔드**: Rails API 서버
- **프론트엔드**: React 애플리케이션
- **세션 저장소**: Redis (인메모리 데이터 저장)
- **영구 데이터 저장소**: 관계형 데이터베이스

## 2. 데이터 모델

### 2.1 데이터베이스 모델

#### 임시 유저 (TemporaryUser)

| 필드명 | 데이터 타입 | 설명 |
| ------ | ------------ | ----- |
| id | integer | 고유 식별자 |
| email | string | 이메일 주소 |
| temp_password_digest | string | 임시 비밀번호 해시 (bcrypt) |
| temp_password_expires_at | datetime | 임시 비밀번호 만료 시간 |
| company_id | integer | 회사 ID (외래 키) |
| partner_id | integer | 거래처 ID (외래 키) |
| current_session_id | string | 현재 활성 세션 ID |
| last_login_at | datetime | 마지막 로그인 시간 |
| created_at | datetime | 생성 시간 |
| updated_at | datetime | 수정 시간 |

**인덱스**:

- `[:email, :company_id, :partner_id]` (유니크)

#### 세션 로그 (SessionLog)

| 필드명 | 데이터 타입 | 설명 |
| ------ | ------------ | ----- |
| id | integer | 고유 식별자 |
| session_id | string | 세션 식별자 |
| email | string | 사용자 이메일 |
| company_id | integer | 회사 ID (외래 키) |
| partner_id | integer | 거래처 ID (외래 키) |
| ip_address | string | 접속 IP 주소 |
| user_agent | string | 사용자 에이전트 |
| fingerprint_hash | string | 브라우저/디바이스 식별 해시 |
| created_at | datetime | 세션 생성 시간 |
| terminated_at | datetime | 세션 종료 시간 |
| termination_reason | string | 종료 이유 (만료, 로그아웃, 강제 종료 등) |

### 2.2 Redis 데이터 구조

#### 세션 데이터

- **키**: `session:{session_id}`
- **값**: 해시 맵
  - `email`: 사용자 이메일
  - `user_id`: 임시 유저 ID
  - `company_id`: 회사 ID
  - `partner_id`: 거래처 ID
  - `fingerprint`: 사용자 환경 핑거프린트
  - `login_time`: 로그인 시간
  - `last_activity`: 마지막 활동 시간
- **TTL**: 8시간 (설정 가능)

#### 사용자-세션 매핑

- **키**: `user_session:{email}:{company_id}:{partner_id}`
- **값**: 현재 활성 세션 ID
- **TTL**: 세션과 동일

## 3. 인증 흐름

### 3.1 로그인 요청 및 임시 비밀번호 생성

1. 사용자 이메일 주소 제출
2. 임시 비밀번호 생성 (10자리 영숫자 조합)
3. 임시 비밀번호 bcrypt로 해시화하여 데이터베이스 저장
4. 테스트용 URL 생성 (실제 이메일 전송 대체)
5. 개발 환경에서 화면에 임시 비밀번호와 URL 표시

### 3.2 로그인 인증

1. 사용자 이메일과 임시 비밀번호 입력
2. 비밀번호 해시 검증
3. 기존 활성 세션 확인:
   - 기존 세션 있을 경우 강제 종료 및 로그 기록
4. 새 세션 생성:
   - 세션 ID 생성
   - 사용자 환경 핑거프린트 생성 및 저장
   - 세션 데이터 Redis에 저장 (TTL 설정)
   - 사용자-세션 매핑 업데이트
5. 사용자의 `current_session_id` 업데이트
6. 세션 로그 생성

### 3.3 세션 검증 및 유지

1. 모든 API 요청에서 세션 ID 쿠키 확인
2. Redis에서 세션 데이터 조회
3. 세션 유효성 검증:
   - 세션 존재 확인
   - 사용자 환경 핑거프린트 일치 확인
   - 세션 만료 시간 확인
4. 세션 활성 시간 갱신 (Redis TTL 갱신)
5. `last_activity` 시간 업데이트

### 3.4 로그아웃 처리

1. Redis에서 세션 데이터 제거
2. 사용자-세션 매핑 제거
3. 세션 ID 쿠키 제거
4. 세션 로그 업데이트 (종료 시간 및 이유)

## 4. 보안 메커니즘

### 4.1 세션 하이재킹 방지

1. 로그인 성공 시 새로운 세션 ID 생성
2. 사용자 환경 핑거프린트 생성 및 저장:
   - IP 주소, 사용자 에이전트, 브라우저 특성 등 조합
   - SHA-256 해시 함수로 핑거프린트 해시 생성
3. 각 요청마다 핑거프린트 일치 여부 확인
4. 불일치 시 추가 인증 요구 또는 세션 종료

### 4.2 중복 로그인 관리

1. 로그인 시 사용자-세션 매핑 확인
2. 기존 활성 세션 있는 경우:
   - Redis에서 기존 세션 데이터 조회
   - 기존 세션 데이터에 강제 종료 플래그 설정
   - 세션 로그에 "새 로그인에 의한 종료" 기록
3. 각 요청마다 강제 종료 플래그 확인
4. 강제 종료된 세션은 자동 로그아웃 처리하고 사용자에게 알림

### 4.3 세션 시간 관리

1. 절대 만료 시간 설정 (예: 8시간)
2. 비활성 타임아웃 설정 (예: 30분)
3. Redis TTL 기능 활용한 자동 만료
4. 만료 임박 시 사용자에게 알림 및 연장 옵션 제공

## 5. API 설계

### 5.1 인증 관련 엔드포인트

#### 임시 비밀번호 요청

- **URL**: `POST /api/v1/auth/request_temp_password`
- **Parameters**:
  - `email`: 사용자 이메일
  - `company_id`: 회사 ID
  - `partner_id`: 거래처 ID
- **Response**:
  - 성공 시: 200 OK

    ```json
    {
      "message": "임시 비밀번호가 생성되었습니다.",
      "debug_info": {
        "temp_password": "a1b2c3d4e5",
        "login_url": "https://example.com/auth/temp-login/token123",
        "expires_at": "2023-01-01T12:30:00Z"
      }
    }
    ```

#### 로그인 인증

- **URL**: `POST /api/v1/auth/login`
- **Parameters**:
  - `email`: 사용자 이메일
  - `password`: 임시 비밀번호
  - `company_id`: 회사 ID
  - `partner_id`: 거래처 ID
- **Response**:
  - 성공 시: 200 OK

    ```json
    {
      "message": "로그인 성공",
      "user": {
        "email": "user@example.com",
        "company_id": 1,
        "partner_id": 2
      }
    }
    ```

  - 실패 시: 401 Unauthorized

#### 로그아웃

- **URL**: `POST /api/v1/auth/logout`
- **Parameters**: 없음 (세션 쿠키 사용)
- **Response**:
  - 성공 시: 200 OK

    ```json
    {
      "message": "로그아웃 되었습니다."
    }
    ```

#### 세션 상태 확인

- **URL**: `GET /api/v1/auth/session_status`
- **Parameters**: 없음 (세션 쿠키 사용)
- **Response**:
  - 성공 시: 200 OK

    ```json
    {
      "authenticated": true,
      "session_expires_at": "2023-01-01T18:30:00Z",
      "user": {
        "email": "user@example.com",
        "company_id": 1,
        "partner_id": 2
      }
    }
    ```

  - 세션 없음: 401 Unauthorized

#### 세션 갱신

- **URL**: `POST /api/v1/auth/renew_session`
- **Parameters**: 없음 (세션 쿠키 사용)
- **Response**:
  - 성공 시: 200 OK

    ```json
    {
      "message": "세션이 갱신되었습니다.",
      "session_expires_at": "2023-01-01T18:30:00Z"
    }
    ```

### 5.2 테스트용 엔드포인트

#### 테스트용 URL 로그인

- **URL**: `GET /api/v1/auth/temp_login/:token`
- **Parameters**:
  - `token`: 임시 로그인 토큰
- **Response**: 프론트엔드 로그인 페이지로 리디렉션

## 6. 프론트엔드 구현 방향

### 6.1 인증 상태 관리

- React Context API 활용한 인증 상태 관리
- 초기 렌더링 시 세션 상태 확인
- 로그인/로그아웃 함수 구현
- 세션 갱신 로직 구현

### 6.2 인증 화면 구성

#### 이메일 입력 화면

- 사용자 이메일 입력 UI
- 회사 ID와 거래처 ID 포함 (URL 파라미터 또는 선택 UI)
- 임시 비밀번호 요청 기능

#### 비밀번호 입력 화면

- 임시 비밀번호 입력 UI
- 로그인 인증 처리
- 테스트 환경에서 자동 채움 옵션

#### 세션 관리 UI

- 세션 만료 임박 시 알림 표시
- 세션 갱신 옵션
- 다른 기기 로그인 발생 시 알림 표시

### 6.3 API 통신 설정

- Fetch API 활용
- 자격 증명 포함 설정 (credentials: 'include')
- 응답 상태 코드 확인을 통한 인증 오류 처리
- 세션 무효화 처리

## 7. 테스트 방안

### 7.1 테스트 환경 설정

- 개발 모드에서 임시 비밀번호 직접 표시
- 테스트용 로그인 URL 생성 및 표시
- 자동 로그인 옵션 제공

### 7.2 테스트 시나리오

#### 기본 인증 흐름

- 임시 비밀번호 생성 및 로그인
- 세션 유지 및 갱신
- 로그아웃

#### 보안 기능 테스트

- 세션 하이재킹 시도 시 세션 종료 확인
- 다른 브라우저에서 로그인 시 기존 세션 종료 확인
- 세션 타임아웃 동작 확인

#### 엣지 케이스

- 만료된 임시 비밀번호 사용 시도
- 잘못된 비밀번호 입력
- 세션 쿠키 조작 시도

## 8. 구현 시 고려사항

### 8.1 보안 설정

#### 쿠키 설정

- HTTPOnly 플래그 설정
- Secure 플래그 설정 (HTTPS 환경)
- SameSite 속성 설정 (Lax 권장)
- 적절한 만료 시간 설정

#### CORS 설정

- 프론트엔드 도메인만 허용
- credentials: true 설정
- 필요한 HTTP 메소드만 허용

### 8.2 성능 최적화

#### Redis 설정

- 적절한 TTL 설정
- 세션 데이터 최소화
- 필요 시 Redis 클러스터 구성 고려

#### 세션 검증 최적화

- 불필요한 데이터베이스 조회 최소화
- 핑거프린트 검증 로직 최적화

### 8.3 사용자 경험 개선

#### 오류 처리

- 명확한 오류 메시지 제공
- 인증 실패 시 적절한 안내 제공
- 세션 만료 시 사용자 친화적 처리

#### 상태 피드백

- 로딩 상태 표시
- 인증 처리 진행 상황 표시
- 세션 상태 정보 제공

## 9. 개발 로드맵

### 9.1 1단계: 기본 인증 시스템

- 데이터베이스 모델 구현
- Redis 연동 설정
- 기본 인증 API 개발
- 프론트엔드 인증 화면 구현

### 9.2 2단계: 보안 강화

- 세션 하이재킹 방지 구현
- 중복 로그인 관리 구현
- 세션 시간 관리 기능 추가

### 9.3 3단계: 테스트 및 개선

- 테스트 시나리오 구현
- 엣지 케이스 처리
- 성능 및 사용자 경험 개선
- 오류 처리 강화

## 10. 결론

이 설계서는 Rails 백엔드와 React 프론트엔드를 사용한 임시 유저 인증 시스템의 핵심 기능과 구현 방향을 제시함. Redis를 세션 저장소로 활용하여 성능을 확보하고, 세션 하이재킹 방지와 중복 로그인 관리 기능을 통해 보안을 강화함. 실제 이메일 전송 대신 테스트용 URL을 제공하여 개발 및 테스트 환경에서 쉽게 사용할 수 있도록 함.
