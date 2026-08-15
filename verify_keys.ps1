# Local-only API key verification script.
# Run this yourself: `powershell -ExecutionPolicy Bypass -File verify_keys.ps1`
# Reads keys from env.json / android/local.properties on THIS machine only.
# Never prints raw key values - only pass/fail and short response snippets.

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$envJsonPath = Join-Path $root "env.json"
$localPropsPath = Join-Path $root "android\local.properties"

if (-not (Test-Path $envJsonPath)) {
    Write-Output "env.json not found at $envJsonPath - aborting."
    exit 1
}
if (-not (Test-Path $localPropsPath)) {
    Write-Output "android/local.properties not found at $localPropsPath - aborting."
    exit 1
}

$envJson = Get-Content $envJsonPath -Raw | ConvertFrom-Json
$localProps = Get-Content $localPropsPath
function Get-PropValue($lines, $key) {
    $line = $lines | Where-Object { $_ -match "^\s*$([regex]::Escape($key))\s*=" } | Select-Object -First 1
    if (-not $line) { return "" }
    return ($line -split "=", 2)[1].Trim()
}

$backboardKey = $envJson.BACKBOARD_API_KEY
$geminiKey    = $envJson.GEMINI_API_KEY
$orsKey       = $envJson.ORS_API_KEY
$mapsKey      = Get-PropValue $localProps "MAPS_API_KEY"

Write-Output "=== 1. Backboard (POST /threads/messages) ==="
if (-not $backboardKey) {
    Write-Output "FAIL: BACKBOARD_API_KEY is empty in env.json"
} else {
    try {
        $body = @{
            content      = "ping"
            llm_provider = "openrouter"
            model_name   = "anthropic/claude-haiku-4.5"
            stream       = $false
        } | ConvertTo-Json
        $resp = Invoke-RestMethod -Method Post -Uri "https://app.backboard.io/api/threads/messages" `
            -Headers @{ "X-API-Key" = $backboardKey; "Content-Type" = "application/json" } `
            -Body $body -TimeoutSec 20
        Write-Output "PASS: HTTP 200, status=$($resp.status)"
    } catch {
        $statusCode = $null
        $respBody = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $respBody = $reader.ReadToEnd()
            } catch {}
        }
        Write-Output "FAIL: HTTP $statusCode"
        if ($respBody) {
            Write-Output "  response body: $respBody"
        } else {
            Write-Output "  $($_.Exception.Message)"
        }
        Write-Output "  A 401 here means Backboard rejected the key itself - check for:"
        Write-Output "  - the key being stale/rotated/revoked since env.json was last set"
        Write-Output "  - leading/trailing whitespace or truncation from copy-pasting"
        Write-Output "  - the key belonging to a different Backboard account/project"
    }
}

Write-Output ""
Write-Output "=== 2. OpenRouteService (GET /v2/directions/foot-walking) ==="
if (-not $orsKey) {
    Write-Output "FAIL: ORS_API_KEY is empty in env.json"
} else {
    try {
        $uri = "https://api.openrouteservice.org/v2/directions/foot-walking?api_key=$orsKey&start=120.9750,14.5906&end=120.9736,14.5915"
        $resp = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 20
        Write-Output "PASS: HTTP 200, route received."
    } catch {
        Write-Output "FAIL: $($_.Exception.Message)"
    }
}

Write-Output ""
Write-Output "=== 3. Gemini (generateContent, plain text) ==="
if (-not $geminiKey) {
    Write-Output "FAIL: GEMINI_API_KEY is empty in env.json"
} else {
    # Try a couple of model names since availability varies by account/
    # API version - a 404 on one specific model name does not necessarily
    # mean the key itself is bad.
    $modelsToTry = @("gemini-2.0-flash", "gemini-1.5-flash", "gemini-2.5-flash-lite")
    $succeeded = $false
    foreach ($model in $modelsToTry) {
        try {
            $uri = "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=$geminiKey"
            $body = @{ contents = @(@{ parts = @(@{ text = "ping" }) }) } | ConvertTo-Json -Depth 5
            $resp = Invoke-RestMethod -Method Post -Uri $uri -ContentType "application/json" -Body $body -TimeoutSec 20
            Write-Output "PASS: HTTP 200 on model '$model', model responded."
            $succeeded = $true
            break
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
            Write-Output "  model '$model' failed: HTTP $statusCode - $($_.Exception.Message)"
        }
    }
    if (-not $succeeded) {
        Write-Output "FAIL: all tried models failed. If every attempt returned 404,"
        Write-Output "the API version/model names are likely stale, not the key itself."
        Write-Output "If any attempt returned 400/401/403, the key itself is the problem"
        Write-Output "(invalid, revoked, or lacking Generative Language API access)."
    }
}

Write-Output ""
Write-Output "=== 4. Google Maps SDK for Android key ==="
if (-not $mapsKey) {
    Write-Output "FAIL: MAPS_API_KEY is empty in android/local.properties"
} else {
    Write-Output "This key is restricted to Android apps (package name + SHA-1), so it"
    Write-Output "cannot be validated with a generic HTTP call from a script - an"
    Write-Output "unrestricted-looking call would either be rejected regardless of"
    Write-Output "validity, or worse, succeed only because it is not properly restricted."
    Write-Output "Check it directly instead:"
    Write-Output "  1. Google Cloud Console: APIs and Services > Credentials > this key"
    Write-Output "  2. Confirm Maps SDK for Android is in its API restrictions list"
    Write-Output "  3. Confirm its Android app restrictions list your release package name"
    Write-Output "     (e.g. com.example.intravel) plus your RELEASE keystore SHA-1"
    Write-Output "     (not just the debug keystore SHA-1)."
    Write-Output "  4. Get the release SHA-1 via:"
    Write-Output "     keytool -list -v -keystore your-release-keystore.jks -alias your-alias"
}
