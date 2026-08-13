[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$AssetPath,
    [string]$Tag
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$schemaPath = Join-Path $root 'schemas/update-manifest-v1.schema.json'
$schemaReference = '../../../schemas/update-manifest-v1.schema.json'
$versionPattern = '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
$sha256Pattern = '^[a-f0-9]{64}$'
$productNames = @{
    'akc-sms' = 'SMS'
    'akc-pms' = 'PMS'
}

function Test-HasProperty {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    return $null -ne $Object.PSObject.Properties[$Name]
}

function Add-ValidationError {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Errors,
        [Parameter(Mandatory)][string]$Message
    )

    $Errors.Add($Message)
}

function Read-JsonObject {
    param([Parameter(Mandatory)][string]$Path)

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $raw = Get-Content -LiteralPath $resolved -Raw -Encoding UTF8
    $convertFromJson = Get-Command ConvertFrom-Json
    if ($convertFromJson.Parameters.ContainsKey('DateKind')) {
        $value = $raw | ConvertFrom-Json -DateKind String
    }
    else {
        $value = $raw | ConvertFrom-Json
    }
    if ($null -eq $value -or $value -is [System.Array]) {
        throw "JSON 루트는 객체여야 합니다: $resolved"
    }

    return [PSCustomObject]@{
        Path = $resolved
        Raw = $raw
        Value = $value
    }
}

function Test-Manifest {
    param(
        [Parameter(Mandatory)]$Manifest,
        [string]$ExpectedProductId,
        [string]$ExpectedChannel
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $allowedProperties = @(
        '$schema', 'schemaVersion', 'productId', 'channel', 'enabled',
        'version', 'mandatory', 'releaseNotes', 'publishedAtUtc', 'installer'
    )
    foreach ($property in $Manifest.PSObject.Properties.Name) {
        if ($property -notin $allowedProperties) {
            Add-ValidationError $errors "허용되지 않은 최상위 필드입니다: $property"
        }
    }

    foreach ($required in @('schemaVersion', 'productId', 'channel', 'enabled')) {
        if (-not (Test-HasProperty $Manifest $required)) {
            Add-ValidationError $errors "필수 필드가 없습니다: $required"
        }
    }

    if ((Test-HasProperty $Manifest 'schemaVersion') -and $Manifest.schemaVersion -ne 1) {
        Add-ValidationError $errors 'schemaVersion은 1이어야 합니다.'
    }

    $productId = if (Test-HasProperty $Manifest 'productId') { [string]$Manifest.productId } else { '' }
    if (-not $productNames.ContainsKey($productId)) {
        Add-ValidationError $errors "지원하지 않는 productId입니다: $productId"
    }
    if ($ExpectedProductId -and $productId -ne $ExpectedProductId) {
        Add-ValidationError $errors "경로의 제품($ExpectedProductId)과 productId($productId)가 다릅니다."
    }

    $channel = if (Test-HasProperty $Manifest 'channel') { [string]$Manifest.channel } else { '' }
    if ($channel -notin @('stable', 'staging')) {
        Add-ValidationError $errors "지원하지 않는 channel입니다: $channel"
    }
    if ($ExpectedChannel -and $channel -ne $ExpectedChannel) {
        Add-ValidationError $errors "파일명의 채널($ExpectedChannel)과 channel($channel)이 다릅니다."
    }

    $enabled = $false
    if (Test-HasProperty $Manifest 'enabled') {
        if ($Manifest.enabled -isnot [bool]) {
            Add-ValidationError $errors 'enabled는 boolean이어야 합니다.'
        }
        else {
            $enabled = $Manifest.enabled
        }
    }

    if ($enabled) {
        foreach ($required in @('version', 'mandatory', 'releaseNotes', 'publishedAtUtc', 'installer')) {
            if (-not (Test-HasProperty $Manifest $required)) {
                Add-ValidationError $errors "활성 채널의 필수 필드가 없습니다: $required"
            }
        }
    }

    $version = ''
    if (Test-HasProperty $Manifest 'version') {
        $version = [string]$Manifest.version
        if ($version -notmatch $versionPattern) {
            Add-ValidationError $errors "version은 4자리 숫자 버전이어야 합니다: $version"
        }
    }

    if ((Test-HasProperty $Manifest 'mandatory') -and $Manifest.mandatory -isnot [bool]) {
        Add-ValidationError $errors 'mandatory는 boolean이어야 합니다.'
    }
    if (Test-HasProperty $Manifest 'releaseNotes') {
        $releaseNotes = [string]$Manifest.releaseNotes
        if ([string]::IsNullOrWhiteSpace($releaseNotes) -or $releaseNotes.Length -gt 10000) {
            Add-ValidationError $errors 'releaseNotes는 1~10000자의 내용이어야 합니다.'
        }
    }
    if (Test-HasProperty $Manifest 'publishedAtUtc') {
        $publishedAtUtc = [string]$Manifest.publishedAtUtc
        $isValidUtc = $publishedAtUtc.EndsWith('Z', [StringComparison]::Ordinal)
        if ($isValidUtc) {
            try {
                [void][System.Xml.XmlConvert]::ToDateTimeOffset($publishedAtUtc)
            }
            catch {
                $isValidUtc = $false
            }
        }
        if (-not $isValidUtc) {
            Add-ValidationError $errors 'publishedAtUtc는 Z로 끝나는 유효한 UTC ISO 8601 값이어야 합니다.'
        }
    }

    if (Test-HasProperty $Manifest 'installer') {
        $installer = $Manifest.installer
        if ($null -eq $installer -or $installer -is [string] -or $installer -is [System.Array]) {
            Add-ValidationError $errors 'installer는 객체여야 합니다.'
        }
        else {
            $allowedInstallerProperties = @('fileName', 'url', 'size', 'sha256')
            foreach ($property in $installer.PSObject.Properties.Name) {
                if ($property -notin $allowedInstallerProperties) {
                    Add-ValidationError $errors "허용되지 않은 installer 필드입니다: $property"
                }
            }
            foreach ($required in $allowedInstallerProperties) {
                if (-not (Test-HasProperty $installer $required)) {
                    Add-ValidationError $errors "installer 필수 필드가 없습니다: $required"
                }
            }

            if ($productNames.ContainsKey($productId) -and $version -match $versionPattern) {
                $productName = $productNames[$productId]
                $expectedTag = "$productId-v$version"
                $expectedFileName = "AKC-$productName-Setup-$version.exe"
                $expectedUrl = "https://github.com/AKC-SW-Team/AKC-Update/releases/download/$expectedTag/$expectedFileName"

                if ((Test-HasProperty $installer 'fileName') -and [string]$installer.fileName -cne $expectedFileName) {
                    Add-ValidationError $errors "installer.fileName이 규칙과 다릅니다. 예상: $expectedFileName"
                }
                if ((Test-HasProperty $installer 'url') -and [string]$installer.url -cne $expectedUrl) {
                    Add-ValidationError $errors "installer.url이 버전 고정 Release URL과 다릅니다. 예상: $expectedUrl"
                }
            }

            if (Test-HasProperty $installer 'size') {
                $size = $installer.size
                if (($size -isnot [int] -and $size -isnot [long]) -or [long]$size -lt 1) {
                    Add-ValidationError $errors 'installer.size는 1 이상의 정수여야 합니다.'
                }
            }
            if ((Test-HasProperty $installer 'sha256') -and [string]$installer.sha256 -notmatch $sha256Pattern) {
                Add-ValidationError $errors 'installer.sha256은 소문자 64자리 SHA-256이어야 합니다.'
            }
        }
    }

    return $errors
}

function Assert-NoErrors {
    param(
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Errors
    )

    if ($Errors.Count -gt 0) {
        $details = ($Errors | ForEach-Object { "  - $_" }) -join [Environment]::NewLine
        throw "$Subject 검증 실패:$([Environment]::NewLine)$details"
    }
}

if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
    throw "JSON Schema 파일이 없습니다: $schemaPath"
}
$schemaDocument = Read-JsonObject $schemaPath
if (-not (Test-HasProperty $schemaDocument.Value '$schema') -or
    [string]$schemaDocument.Value.'$schema' -ne 'http://json-schema.org/draft-07/schema#') {
    throw 'JSON Schema는 draft-07을 명시해야 합니다.'
}

if ($ManifestPath) {
    if (-not $AssetPath -or -not $Tag) {
        throw '배포 후보 검증에는 ManifestPath, AssetPath, Tag가 모두 필요합니다.'
    }

    $candidate = Read-JsonObject $ManifestPath
    $candidateErrors = @(Test-Manifest $candidate.Value)
    Assert-NoErrors $candidate.Path $candidateErrors

    if (-not $candidate.Value.enabled) {
        throw '배포 후보 매니페스트는 enabled=true여야 합니다.'
    }

    $expectedTag = "$($candidate.Value.productId)-v$($candidate.Value.version)"
    if ($Tag -cne $expectedTag) {
        throw "태그가 매니페스트와 다릅니다. 예상: $expectedTag"
    }

    $asset = (Resolve-Path -LiteralPath $AssetPath).Path
    if ([IO.Path]::GetFileName($asset) -cne [string]$candidate.Value.installer.fileName) {
        throw "설치 파일명이 매니페스트와 다릅니다. 예상: $($candidate.Value.installer.fileName)"
    }
    $assetInfo = Get-Item -LiteralPath $asset
    if ($assetInfo.Length -ne [long]$candidate.Value.installer.size) {
        throw "설치 파일 크기가 매니페스트와 다릅니다. 실제: $($assetInfo.Length), 매니페스트: $($candidate.Value.installer.size)"
    }
    $actualHash = (Get-FileHash -LiteralPath $asset -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -cne [string]$candidate.Value.installer.sha256) {
        throw "설치 파일 SHA-256이 매니페스트와 다릅니다. 실제: $actualHash"
    }

    Write-Host "[OK] 배포 후보: $($candidate.Path)"
    Write-Host "[OK] 태그: $Tag"
    Write-Host "[OK] 설치 파일: $asset"
    exit 0
}

if ($AssetPath -or $Tag) {
    throw 'AssetPath와 Tag는 ManifestPath와 함께 사용해야 합니다.'
}

$expectedManifests = @(
    @{ ProductId = 'akc-sms'; Channel = 'stable' },
    @{ ProductId = 'akc-sms'; Channel = 'staging' },
    @{ ProductId = 'akc-pms'; Channel = 'stable' },
    @{ ProductId = 'akc-pms'; Channel = 'staging' }
)
$expectedPaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$manifestCount = 0

foreach ($expected in $expectedManifests) {
    $relativePath = "products/$($expected.ProductId)/channels/$($expected.Channel).json"
    [void]$expectedPaths.Add($relativePath)
    $path = Join-Path $root ($relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "필수 채널 매니페스트가 없습니다: $relativePath"
    }

    $document = Read-JsonObject $path
    $errors = @(Test-Manifest $document.Value $expected.ProductId $expected.Channel)
    if (-not (Test-HasProperty $document.Value '$schema') -or
        [string]$document.Value.'$schema' -ne $schemaReference) {
        $errors += "추적 매니페스트의 `$schema는 '$schemaReference'여야 합니다."
    }

    $testJsonCommand = Get-Command Test-Json -ErrorAction SilentlyContinue
    if ($null -ne $testJsonCommand) {
        try {
            if (-not (Test-Json -Json $document.Raw -SchemaFile $schemaPath -ErrorAction Stop)) {
                $errors += 'JSON Schema 검증에 실패했습니다.'
            }
        }
        catch {
            $errors += "JSON Schema 검증 오류: $($_.Exception.Message)"
        }
    }

    Assert-NoErrors $relativePath $errors
    Write-Host "[OK] $relativePath"
    $manifestCount++
}

$allTrackedManifests = Get-ChildItem -LiteralPath (Join-Path $root 'products') -Filter '*.json' -File -Recurse
foreach ($file in $allTrackedManifests) {
    $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
    if (-not $expectedPaths.Contains($relative)) {
        throw "등록되지 않은 채널 매니페스트입니다: $relative"
    }
}

Write-Host "검증 완료: 채널 매니페스트 ${manifestCount}개"
