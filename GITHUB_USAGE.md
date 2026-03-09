# GitHub Adapter Usage (Redmine 6.0)

이 문서는 `feature/github-adapter` 브랜치 기준 GitHub 저장소 연동 방법을 설명합니다.

## 1. 사전 준비

1. Redmine 6.0 환경에서 플러그인 코드를 최신으로 반영합니다.
2. Redmine 컨테이너(또는 서버)에서 의존성을 설치합니다.

```bash
bundle install
```

3. Redmine를 재시작합니다.

## 2. GitHub API Token 준비

1. GitHub에서 Personal Access Token(PAT)을 생성합니다.
2. 최소 권한:
   - Private 저장소: `repo`
   - Public 저장소만 사용: `public_repo`
3. 토큰은 Redmine 저장소 설정의 `GitHub API Token` 필드에 입력합니다.

## 3. Redmine 관리자 설정

1. `Administration -> Settings -> Repositories` 이동
2. SCM 목록에서 `Github` 활성화
3. 저장

## 4. 프로젝트 저장소 연결

1. 프로젝트 `Settings -> Repositories -> New repository`
2. SCM: `Github` 선택
3. 필드 입력:
   - `URL`
     - GitHub.com: `https://github.com/<owner>/<repo>.git`
     - GitHub Enterprise: `https://<ghe-host>/<owner>/<repo>.git`
   - `GitHub API Token`
     - 위에서 발급한 PAT
   - `Root URL` (선택)
     - GitHub.com: `https://github.com`
     - Enterprise: `https://<ghe-host>` 또는 컨텍스트 경로 포함 URL
4. 저장 후 브랜치/태그/커밋 화면을 확인합니다.

## 5. 동작 확인 체크리스트

1. 저장소 생성 후 오류 없이 저장되는지 확인
2. 브랜치 목록이 표시되는지 확인
3. 태그 목록이 표시되는지 확인
4. 파일 트리/파일 내용 조회가 되는지 확인
5. 커밋/변경셋 동기화가 되는지 확인

## 6. 문제 해결

1. `401/403` 오류:
   - 토큰 권한 부족 또는 만료 가능성이 큽니다.
2. Enterprise 환경에서 연결 실패:
   - `Root URL` 값을 Enterprise URL로 정확히 입력했는지 확인합니다.
3. 화면에서 GitHub 전용 입력 필드가 안 보일 때:
   - 컨테이너 재시작 후 다시 확인합니다.
   - 플러그인 코드가 최신 브랜치(`feature/github-adapter`)인지 확인합니다.

