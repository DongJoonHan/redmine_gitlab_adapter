# Redmine Gitlab Adapter Plugin

This repository is a fork of the original project and has been modified to support Redmine 6.0.

For Redmine 6.0.x.

### Plugin installation

1.  Copy the plugin directory into the $REDMINE_ROOT/plugins directory. Please
    note that plugin's folder name should be "redmine_gitlab_adapter".

2.  Install 'gitlab'

    e.g. bundle install

3.  (Re)Start Redmine.

### Settings

1.  Login redmine used redmine admin account.

2.  Open top menu "Administration" -> "Settings" -> "Repositories" page

3.  Enabled "Gitlab" SCM.

4.  Apply this configure.

### How to use

1.  Login redmine used the project admin account.

2.  Open this project "Settings" -> "Repositories" page.

3.  Click "New reposiory".

4.  Select "Gitlab" from SCM Pull Down Menu.

5.  Paste `<Gitlab Project URL>` into "URL".

6.  Paste `<Gitlab API Access Token>` into "API Token".

7.  Click "Create" button.

---

## 한국어 안내

이 저장소는 원본 프로젝트를 포크한 뒤, Redmine 6.0을 지원하도록 수정한 버전입니다.

Redmine 6.0.x에서 사용합니다.

### 플러그인 설치

1.  플러그인 디렉터리를 `$REDMINE_ROOT/plugins` 디렉터리에 복사합니다.
    플러그인 폴더 이름은 반드시 `redmine_gitlab_adapter` 여야 합니다.
    또는
    ```
    git clone https://github.com/DongJoonHan/redmine_gitlab_adapter.git
    ```

3.  `gitlab` gem을 설치합니다.

    예: `bundle install`

4.  Redmine을 (재)시작합니다.

### 설정

1.  Redmine 관리자 계정으로 로그인합니다.

2.  상단 메뉴에서 "Administration" -> "Settings" -> "Repositories" 페이지로 이동합니다.

3.  SCM에서 "Gitlab"을 활성화합니다.

4.  설정을 적용합니다.

### 사용 방법

1.  프로젝트 관리자 계정으로 로그인합니다.

2.  해당 프로젝트의 "Settings" -> "Repositories" 페이지로 이동합니다.

3.  "New repository"를 클릭합니다.

4.  SCM 드롭다운에서 "Gitlab"을 선택합니다.

5.  `<Gitlab Project URL>`을 "URL"에 입력합니다.

6.  `<Gitlab API Access Token>`을 "API Token"에 입력합니다.

7.  "Create" 버튼을 클릭합니다.
