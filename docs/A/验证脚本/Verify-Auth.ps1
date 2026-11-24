param([string]$BaseUrl = 'http://localhost:8080')
$ErrorActionPreference = 'Stop'

function Check-Route ($Path, $Expected, $Session, $Method = 'GET', $Location = '') {
    $result = Invoke-WebRequest -Uri "$BaseUrl$Path" -Method $Method -WebSession $Session `
        -MaximumRedirection 0 -SkipHttpErrorCheck -ErrorAction SilentlyContinue
    if ([int]$result.StatusCode -ne $Expected) {
        throw "$Method $Path expected $Expected, got $($result.StatusCode)"
    }
    if ($Location -and !([string]$result.Headers.Location).EndsWith($Location)) {
        throw "$Method $Path expected redirect to $Location"
    }
    if ($Expected -eq 200 -and $result.Content -match '<title>操作失败</title>|<h2>操作失败</h2>') {
        throw "$Method $Path returned an application error page"
    }
    Write-Host "$Method $Path -> $Expected"
    return $result
}

function Login ($Username) {
    $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
    $result = Invoke-WebRequest "$BaseUrl/login" -Method POST -WebSession $session `
        -Body @{ username = $Username; password = '123456' } -MaximumRedirection 0 `
        -SkipHttpErrorCheck -ErrorAction SilentlyContinue
    if ([int]$result.StatusCode -ne 302 -or !([string]$result.Headers.Location).EndsWith('/home')) {
        throw "Login failed for $Username"
    }
    return $session
}

$anonymous = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
Check-Route /home 302 $anonymous GET /login | Out-Null
Check-Route /biz/inbound 302 $anonymous GET /login | Out-Null
Check-Route /biz/stocktake 302 $anonymous POST /login | Out-Null

$buyer = Login lab_buyer
$homePage = Check-Route /home 200 $buyer
if ($homePage.Content -match 'href="[^"]*/biz/stocktake"') { throw 'Buyer can see stocktake menu' }
Check-Route /biz/stocktake 403 $buyer | Out-Null
Check-Route /biz/stocktake 403 $buyer POST | Out-Null
foreach ($path in '/biz/inbound', '/biz/return', '/stock') { Check-Route $path 200 $buyer | Out-Null }
Check-Route /logout 302 $buyer GET /login | Out-Null
Check-Route /stock 302 $buyer GET /login | Out-Null

$keeper = Login lab_keeper
Check-Route /biz/stocktake 200 $keeper | Out-Null
Check-Route /sys/user 403 $keeper | Out-Null
Check-Route /sys/role 403 $keeper | Out-Null
Check-Route /sys/user/add 403 $keeper POST | Out-Null
Check-Route /sys/role/save 403 $keeper POST | Out-Null

$admin = Login lab_admin
'/sys/user', '/sys/role' | ForEach-Object {
    $adminPage = Check-Route $_ 200 $admin
    if ($adminPage.Content -notmatch 'href="[^"]*/sys/user"' -or
        $adminPage.Content -notmatch 'href="[^"]*/sys/role"') {
        throw "Administrator navigation is incomplete on $_"
    }
}
$adminUsers = Check-Route /sys/user 200 $admin
$adminRoles = Check-Route /sys/role 200 $admin
if ($adminUsers.Content -notmatch '<h1>用户管理</h1>' -or
    $adminRoles.Content -notmatch '<h1>权限管理</h1>' -or
    $adminRoles.Content -notmatch 'checked="checked"') {
    throw 'Administrator templates did not render their expected content'
}

$requester = Login lab_requester
foreach ($path in '/biz/materialIssue', '/biz/materialReturn', '/stock') {
    Check-Route $path 200 $requester | Out-Null
}
Check-Route /biz/inbound 403 $requester | Out-Null
