# AKC Update

AKC SMS와 AKC PMS의 공개 업데이트 메타데이터 및 GitHub Release 배포 저장소입니다.

- 다운로드(읽기)는 공개합니다.
- 매니페스트 변경과 Release 게시(쓰기)는 승인된 배포 담당자만 수행합니다.
- 설치 비밀번호 대신 Windows UAC, Authenticode 코드 서명, SHA-256 검증을 사용합니다.
- 모든 채널은 최초 배포 전까지 `enabled: false`입니다.

## 저장소 구조

```text
products/
  akc-sms/channels/stable.json
  akc-sms/channels/staging.json
  akc-pms/channels/stable.json
  akc-pms/channels/staging.json
schemas/
  update-manifest-v1.schema.json
scripts/
  validate-manifests.ps1
docs/
  release-process.md
```

기본 브랜치는 `main`이며 클라이언트 채널 URL은 다음과 같습니다.

| 제품 | 채널 | 매니페스트 URL |
|---|---|---|
| AKC SMS | stable | `https://raw.githubusercontent.com/AKC-SW-Team/AKC-Update/main/products/akc-sms/channels/stable.json` |
| AKC SMS | staging | `https://raw.githubusercontent.com/AKC-SW-Team/AKC-Update/main/products/akc-sms/channels/staging.json` |
| AKC PMS | stable | `https://raw.githubusercontent.com/AKC-SW-Team/AKC-Update/main/products/akc-pms/channels/stable.json` |
| AKC PMS | staging | `https://raw.githubusercontent.com/AKC-SW-Team/AKC-Update/main/products/akc-pms/channels/staging.json` |

기본 브랜치를 변경할 경우 애플리케이션의 매니페스트 URL도 함께 변경해야 합니다.

## 배포 이름 규칙

버전은 항상 `주.부.패치.빌드`의 4자리 숫자를 사용합니다.

| 제품 | 태그 예시 | Release 자산 예시 |
|---|---|---|
| AKC SMS | `akc-sms-v1.2.3.4` | `AKC-SMS-Setup-1.2.3.4.exe` |
| AKC PMS | `akc-pms-v1.2.3.4` | `AKC-PMS-Setup-1.2.3.4.exe` |

GitHub Release 자산에는 폴더 구조가 없습니다. `products/akc-sms` 같은 경로는 Git 저장소 안의 매니페스트 구분용이며, 설치 파일은 Release 자산 루트에 정확한 파일명으로 업로드합니다.

## 검증

저장소의 모든 채널 매니페스트를 검증합니다.

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/validate-manifests.ps1
```

실제 배포 후보 매니페스트, 설치 파일, 태그가 서로 일치하는지도 검증할 수 있습니다.

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/validate-manifests.ps1 `
  -ManifestPath C:\release\stable.candidate.json `
  -AssetPath C:\release\AKC-SMS-Setup-1.2.3.4.exe `
  -Tag akc-sms-v1.2.3.4
```

상세 절차와 GitHub 권한 설정은 [배포 절차](docs/release-process.md)를 참고하십시오.
