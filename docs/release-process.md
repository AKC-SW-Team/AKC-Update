# AKC 업데이트 배포 절차

## 1. 보안 모델

이 저장소는 설치 파일과 업데이트 메타데이터를 누구나 내려받을 수 있는 공개 저장소로 운영합니다. 공개 읽기 권한은 문제가 없지만 쓰기 권한은 다음처럼 제한합니다.

1. 기본 Actions 권한은 `contents: read`로 설정합니다.
2. GitHub 조직에 `update-maintainers` 팀을 만들고 실제 Release 담당자 2명 이상만 등록합니다.
3. `main` 브랜치에 Ruleset을 적용해 Pull Request와 CODEOWNERS 승인을 필수로 합니다.
4. 1인만 등록된 CODEOWNERS에서는 작성자가 자신의 Pull Request를 승인할 수 없어 배포가 잠기므로, 팀 구성 전에는 승인 필수 규칙을 켜지 않습니다.
5. Ruleset에서 강제 푸시와 브랜치 삭제를 금지합니다.
6. `akc-sms-v*`, `akc-pms-v*` 태그 생성 권한은 Release 담당자 또는 전용 GitHub App으로 제한합니다.
7. GitHub의 Immutable Releases를 활성화합니다.
8. Release 담당자는 최소 인원만 저장소에 `Write` 권한으로 등록하고 나머지는 `Read`로 둡니다.
9. 설치 파일 서명 인증서와 비밀번호는 이 공개 저장소에 보관하지 않습니다. 제품 빌드 저장소의 보호된 Secret/Environment에서만 사용합니다.

설치 비밀번호는 자동 업데이트 프로그램 안에 저장해야 하므로 실질적인 비밀이 될 수 없습니다. 설치 권한은 Windows UAC로 제어하고, 파일의 출처와 무결성은 Authenticode 서명과 매니페스트의 SHA-256으로 검증합니다.

## 2. 제품 및 채널

| 제품 ID | 채널 | 용도 |
|---|---|---|
| `akc-sms` | `staging` | 내부 검증용 선배포 |
| `akc-sms` | `stable` | 일반 사용자 배포 |
| `akc-pms` | `staging` | 내부 검증용 선배포 |
| `akc-pms` | `stable` | 일반 사용자 배포 |

`enabled: false`인 채널은 업데이트를 제공하지 않습니다. 최초 Release 게시 및 검증이 끝나기 전에는 모든 채널을 비활성 상태로 유지합니다.

## 3. 태그와 설치 파일 규칙

버전은 `1.2.3.4`처럼 4자리 숫자를 사용하며 태그와 파일명의 대소문자까지 정확히 지킵니다.

| 제품 | 태그 | 설치 파일 |
|---|---|---|
| SMS | `akc-sms-v1.2.3.4` | `AKC-SMS-Setup-1.2.3.4.exe` |
| PMS | `akc-pms-v1.2.3.4` | `AKC-PMS-Setup-1.2.3.4.exe` |

GitHub Release 자산은 폴더를 지원하지 않습니다. Release 페이지에는 `products/akc-sms/...` 같은 폴더를 만들지 않고 설치 파일을 자산 루트에 직접 업로드합니다. 제품 구분은 태그와 파일명으로 수행합니다.

`releases/latest/download/...` 주소는 사용하지 않습니다. 저장소 전체에 latest Release가 하나뿐이라 SMS와 PMS가 서로 덮어쓸 수 있고, 파일 내용도 같은 URL에서 바뀔 수 있기 때문입니다. 매니페스트는 반드시 다음 형태의 버전 고정 URL을 사용합니다.

```text
https://github.com/AKC-SW-Team/AKC-Update/releases/download/akc-sms-v1.2.3.4/AKC-SMS-Setup-1.2.3.4.exe
```

## 4. 배포 후보 준비

1. 제품 저장소에서 4자리 버전으로 Release 빌드를 수행합니다.
2. 설치 EXE에 회사 Authenticode 인증서로 서명하고 타임스탬프를 추가합니다.
3. 서명 검증을 완료한 뒤 파일의 크기와 SHA-256을 계산합니다. 서명 후 파일이 바뀌므로 반드시 서명을 끝낸 파일을 기준으로 계산합니다.
4. 제품 빌드가 생성한 `stable.candidate.json`의 필드를 확인합니다.

활성 매니페스트 예시는 다음과 같습니다.

```json
{
  "schemaVersion": 1,
  "productId": "akc-sms",
  "channel": "stable",
  "enabled": true,
  "version": "1.2.3.4",
  "mandatory": true,
  "releaseNotes": "일정 조회 및 업데이트 안정성 개선",
  "publishedAtUtc": "2026-08-13T06:00:00Z",
  "installer": {
    "fileName": "AKC-SMS-Setup-1.2.3.4.exe",
    "url": "https://github.com/AKC-SW-Team/AKC-Update/releases/download/akc-sms-v1.2.3.4/AKC-SMS-Setup-1.2.3.4.exe",
    "size": 123456789,
    "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  }
}
```

## 5. 배포 후보 검증

배포 PC에서 다음 명령으로 매니페스트, 태그, 실제 설치 파일명, 크기, SHA-256이 모두 일치하는지 확인합니다.

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/validate-manifests.ps1 `
  -ManifestPath C:\release\stable.candidate.json `
  -AssetPath C:\release\AKC-SMS-Setup-1.2.3.4.exe `
  -Tag akc-sms-v1.2.3.4
```

명령이 실패하면 Release를 만들지 않습니다.

## 6. Draft Release 게시

1. 검증한 태그 이름으로 Draft Release를 생성합니다.
2. 검증한 설치 EXE 한 개를 Release 자산 루트에 업로드합니다.
3. 업로드된 자산 이름과 크기를 다시 확인합니다.
4. 승인자가 태그, 자산, 릴리스 노트를 검토합니다.
5. 검토가 끝나면 Release를 게시합니다.

Release가 공개되기 전에는 채널 매니페스트를 활성화하지 않습니다. Immutable Releases를 사용하는 경우 게시 후 자산을 교체하지 말고, 오류가 있으면 새 버전으로 다시 배포합니다.

## 7. staging 승격

1. 대상 제품의 `products/<productId>/channels/staging.json`을 후보 매니페스트로 갱신합니다.
2. `channel`을 `staging`으로 설정하고 `$schema` 상대 경로를 유지합니다.
3. Pull Request를 만들고 `Validate update metadata` 검사를 통과시킵니다.
4. CODEOWNER 승인을 받은 뒤 병합합니다.
5. staging 채널을 사용하는 테스트 PC에서 다운로드, SHA-256, Authenticode, UAC 설치, 재시작 후 버전을 확인합니다.

## 8. stable 승격

1. staging 검증이 끝난 동일 Release 정보를 `products/<productId>/channels/stable.json`에 반영합니다.
2. `channel`만 `stable`로 설정합니다.
3. 별도의 Pull Request와 CODEOWNER 승인을 거쳐 병합합니다.
4. 일반 사용자 PC 한 대에서 업데이트 성공을 확인한 뒤 배포 상황을 모니터링합니다.

## 9. 중지 및 복구

- 아직 설치되지 않은 PC의 배포를 즉시 중지하려면 해당 채널을 `enabled: false`로 바꾸는 긴급 Pull Request를 병합합니다.
- 이미 설치된 버전은 자동으로 이전 버전으로 내리지 않습니다.
- 잘못된 Release 자산을 같은 태그에서 교체하지 않습니다. 수정 버전을 새 태그와 새 파일명으로 빌드해 순방향 복구합니다.
- Release와 매니페스트 변경 이력은 삭제하지 않고 감사 기록으로 유지합니다.

## 10. 저장소 설정 체크리스트

- [ ] 공개 저장소, 불필요한 외부 Collaborator 없음
- [ ] `update-maintainers` 팀에 Release 담당자 2명 이상 등록
- [ ] Actions 기본 권한 `Read repository contents`로 제한
- [ ] `main` Ruleset: PR 필수
- [ ] CODEOWNERS 승인 필수, 최신 승인 무효화 활성화
- [ ] `Validate manifests` 상태 검사 필수
- [ ] 강제 푸시 및 삭제 금지
- [ ] `akc-sms-v*`, `akc-pms-v*` 태그 생성 권한 제한
- [ ] Immutable Releases 활성화
- [ ] 서명 인증서/비밀번호는 제품 저장소의 보호된 Secret에만 보관
