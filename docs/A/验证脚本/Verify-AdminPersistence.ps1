param(
    [Parameter(Mandatory)] [switch]$ConfirmLabWrites,
    [string]$BaseUrl = 'http://localhost:8080',
    [string]$Mysql = 'mysql',
    [string]$DbHost = '127.0.0.1',
    [int]$DbPort = 3306,
    [string]$DbUser = 'root'
)
$ErrorActionPreference = 'Stop'
if (!$ConfirmLabWrites) { throw 'Run against an isolated lab database only.' }

function Read-LabDb ([string]$Sql) {
    $rows = & $Mysql --protocol=TCP "--host=$DbHost" "--port=$DbPort" "--user=$DbUser" `
        --database=warehouse_db --default-character-set=utf8mb4 --batch --raw --skip-column-names "--execute=$Sql"
    if ($LASTEXITCODE -ne 0) { throw 'Database verification query failed.' }
    $rows
}

function Assert-Value ($Actual, $Expected, [string]$Message) {
    if (($Actual -join ',') -cne ($Expected -join ',')) { throw $Message }
    Write-Host "PASS $Message"
}

function New-LabSession ([string]$Username, [string]$Password, [string]$Destination = '/home') {
    $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
    Send-Form /login @{ username = $Username; password = $Password } $session $Destination
    $session
}

function Send-Form ($Path, $Body, $Session, $Destination) {
    $fields = foreach ($key in $Body.Keys) {
        foreach ($value in @($Body[$key])) {
            [uri]::EscapeDataString($key) + '=' + [uri]::EscapeDataString([string]$value)
        }
    }
    $response = Invoke-WebRequest "$BaseUrl$Path" -Method Post -Body ($fields -join '&') -WebSession $Session `
        -ContentType 'application/x-www-form-urlencoded' `
        -MaximumRedirection 0 -SkipHttpErrorCheck -ErrorAction SilentlyContinue
    if ($response.StatusCode -ne 302 -or !([string]$response.Headers.Location).EndsWith($Destination)) {
        $errorText = [regex]::Match([string]$response.Content, '<div class="alert error">([^<]*)</div>').Groups[1].Value
        throw "POST $Path expected 302 to $Destination, got $($response.StatusCode). $errorText"
    }
}

$admin = New-LabSession lab_admin 123456
$account = 'a_verify_' + [guid]::NewGuid().ToString('N').Substring(0, 12)
$row = "FROM sys_user WHERE username = '$account'"
$permissions = 'FROM sys_role_permission rp JOIN sys_permission p ON p.permission_id = rp.permission_id'
$systemFilter = "p.permission_code IN ('user:manage','role:assign')"
$systemBefore = @(Read-LabDb "SELECT CONCAT(role_id,':',permission_code) $permissions WHERE $systemFilter ORDER BY 1")
Assert-Value $systemBefore @('1:role:assign','1:user:manage') 'Only role 1 has the two system permissions'
$roleId = 3
$original = @(Read-LabDb "SELECT rp.permission_id $permissions WHERE role_id=$roleId AND NOT ($systemFilter) ORDER BY 1")
$inbound = Read-LabDb "SELECT permission_id FROM sys_permission WHERE permission_code='biz:inbound'"
if ($original -notcontains $inbound) { throw 'Seed role 3 with 08-rbac-lab.sql first.' }
$changed = @($original | Where-Object { $_ -ne $inbound })
$restoreRole = $false
try {
    Send-Form /sys/user/add @{ username=$account; password='LabOriginal42'; realName='Verification Original'; roleId=3 } $admin /sys/user
    $id = Read-LabDb "SELECT user_id $row"
    if ($id -notmatch '^\d+$') { throw 'Created account was not found.' }
    Assert-Value (Read-LabDb "SELECT CONCAT(real_name,':',role_id,':',status) $row") 'Verification Original:3:1' 'New account persisted with default enabled status'
    $initialPasswordHash = Read-LabDb "SELECT password $row"
    if ($initialPasswordHash -notmatch '^[0-9a-f]{32}:[0-9a-f]{64}$' -or $initialPasswordHash -eq 'LabOriginal42') {
        throw 'New account password was not stored as a salted hash.'
    }
    $null = New-LabSession $account LabOriginal42

    Send-Form /sys/user/update @{ userId=$id; username=$account; password=''; realName='Verification Updated'; roleId=4; status=0 } $admin /sys/user
    Assert-Value (Read-LabDb "SELECT CONCAT(real_name,':',role_id,':',status,':',password='$initialPasswordHash') $row") 'Verification Updated:4:0:1' 'Update persisted name, role and status with password hash unchanged'
    $null = New-LabSession $account LabOriginal42 /login

    Send-Form /sys/user/update @{ userId=$id; username=$account; password='LabUpdated42'; realName='Verification Updated'; roleId=4; status=1 } $admin /sys/user
    Assert-Value (Read-LabDb "SELECT CONCAT(status,':',password<>'$initialPasswordHash',':',password NOT IN ('LabOriginal42','LabUpdated42'),':',password REGEXP '^[0-9a-f]{32}:[0-9a-f]{64}$') $row") '1:1:1:1' 'New password is persisted as a changed salted hash'
    $null = New-LabSession $account LabOriginal42 /login
    $null = New-LabSession $account LabUpdated42

    Send-Form "/sys/user/del/$id" @{} $admin /sys/user
    Assert-Value (Read-LabDb "SELECT COUNT(*) $row") '0' 'Deleted account no longer exists'
    $null = New-LabSession $account LabUpdated42 /login

    $restoreRole = $true
    Send-Form /sys/role/save @{roleId=$roleId; permissionIds=$changed} $admin /sys/role
    Assert-Value @(Read-LabDb "SELECT rp.permission_id $permissions WHERE role_id=$roleId AND NOT ($systemFilter) ORDER BY 1") $changed 'Role save persisted the selected permission set'
    Assert-Value @(Read-LabDb "SELECT CONCAT(role_id,':',permission_code) $permissions WHERE $systemFilter ORDER BY 1") $systemBefore 'System permissions remained exclusive to administrator'
    $buyer = New-LabSession lab_buyer 123456
    $denied = Invoke-WebRequest "$BaseUrl/biz/inbound" -WebSession $buyer -SkipHttpErrorCheck
    Assert-Value ([int]$denied.StatusCode) 403 'Removed permission denied access after new login'
} finally {
    if ($restoreRole) {
        Send-Form /sys/role/save @{roleId=$roleId; permissionIds=$original} $admin /sys/role
        Assert-Value @(Read-LabDb "SELECT rp.permission_id $permissions WHERE role_id=$roleId AND NOT ($systemFilter) ORDER BY 1") $original 'Original role grants restored and verified'
    }
    $remaining = Read-LabDb "SELECT user_id $row"
    if ($remaining -match '^\d+$') { Send-Form "/sys/user/del/$remaining" @{} $admin /sys/user }
}
$buyer = New-LabSession lab_buyer 123456
$restored = Invoke-WebRequest "$BaseUrl/biz/inbound" -WebSession $buyer -SkipHttpErrorCheck
if ($restored.Content -match '<title>操作失败</title>') { throw 'Restored permission rendered an application error' }
Assert-Value ([int]$restored.StatusCode) 200 'Restored permission allows access after new login'
