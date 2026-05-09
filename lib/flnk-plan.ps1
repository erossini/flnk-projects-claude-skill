#!/usr/bin/env pwsh
# flnk-plan.ps1 — thin auth + JSON envelope helper for the FastLinkIt
# Projects API. Used by the Claude Code project-planner skill so the AI
# doesn't have to hand-roll curl with headers each call.
#
# Subcommands:
#   list                                          List the user's projects
#   context  <projectId>                          Get methodology + columns + recent items
#   plan     <projectId> <planJsonPath>           POST a plan (path to JSON file)
#   start    <projectId> <workItemId> [summary]   Open an agent run on an item
#   complete <projectId> <workItemId> <runId> [narrativePath]
#                                                 Close run successfully (narrative is path to file)
#   block    <projectId> <workItemId> <runId> <reason>
#                                                 Close run as Blocked
#
# Env:
#   FLNKIT_API_KEY   — required, scope: projects
#   FLNKIT_API_BASE  — default https://flnk.it
#   FLNKIT_AGENT_ID  — default claude-code

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Command,
    [string] $A1, [string] $A2, [string] $A3, [string] $A4
)

$ErrorActionPreference = 'Stop'

$apiKey  = $env:FLNKIT_API_KEY
$apiBase = if ($env:FLNKIT_API_BASE) { $env:FLNKIT_API_BASE.TrimEnd('/') } else { 'https://flnk.it' }
$agentId = if ($env:FLNKIT_AGENT_ID) { $env:FLNKIT_AGENT_ID } else { 'claude-code' }

if (-not $apiKey) {
    Write-Error "FLNKIT_API_KEY not set. Generate one at $apiBase/Account/Manage/ApiKeys with the 'projects' scope ticked."
    exit 2
}

$headers = @{
    'X-Api-Key'    = $apiKey
    'Accept'       = 'application/json'
    'Content-Type' = 'application/json; charset=utf-8'
}

# Local dev usually runs on a self-signed cert; --skip-cert-check via env to opt in.
if ($apiBase -match 'localhost' -or $env:FLNKIT_INSECURE -eq '1') {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
}

function Invoke-Flnk {
    param([string]$Method, [string]$Path, [object]$Body = $null)
    $url = "$apiBase$Path"
    $params = @{ Method = $Method; Uri = $url; Headers = $headers }
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
    }
    try {
        return Invoke-RestMethod @params
    } catch {
        $resp = $_.Exception.Response
        if ($resp) {
            $reader = [System.IO.StreamReader]::new($resp.GetResponseStream())
            $body = $reader.ReadToEnd()
            Write-Error "API call failed: $($resp.StatusCode) $($resp.StatusDescription)`n$body"
        } else {
            Write-Error $_
        }
        exit 1
    }
}

switch ($Command) {
    'list' {
        Invoke-Flnk -Method GET -Path '/api/projects' | ConvertTo-Json -Depth 10
    }
    'context' {
        if (-not $A1) { Write-Error 'Usage: context <projectId>'; exit 2 }
        Invoke-Flnk -Method GET -Path "/api/projects/$A1/context" | ConvertTo-Json -Depth 10
    }
    'plan' {
        if (-not $A1 -or -not $A2) { Write-Error 'Usage: plan <projectId> <planJsonPath>'; exit 2 }
        if (-not (Test-Path $A2)) { Write-Error "Plan file not found: $A2"; exit 2 }
        $payload = Get-Content -Raw -Path $A2 | ConvertFrom-Json
        Invoke-Flnk -Method POST -Path "/api/projects/$A1/plan" -Body $payload | ConvertTo-Json -Depth 10
    }
    'start' {
        if (-not $A1 -or -not $A2) { Write-Error 'Usage: start <projectId> <workItemId> [summary]'; exit 2 }
        $body = @{ agentId = $agentId; summary = $A3 }
        Invoke-Flnk -Method POST -Path "/api/projects/$A1/work-items/$A2/agent-run/start" -Body $body | ConvertTo-Json -Depth 10
    }
    'complete' {
        if (-not $A1 -or -not $A2 -or -not $A3) { Write-Error 'Usage: complete <projectId> <workItemId> <runId> [narrativePath]'; exit 2 }
        $narrative = $null
        if ($A4) {
            if (-not (Test-Path $A4)) { Write-Error "Narrative file not found: $A4"; exit 2 }
            $narrative = Get-Content -Raw -Path $A4
        }
        $body = @{ narrative = $narrative; skipReview = $false }
        Invoke-Flnk -Method POST -Path "/api/projects/$A1/work-items/$A2/agent-run/$A3/complete" -Body $body | ConvertTo-Json -Depth 10
    }
    'block' {
        if (-not $A1 -or -not $A2 -or -not $A3 -or -not $A4) { Write-Error 'Usage: block <projectId> <workItemId> <runId> <reason>'; exit 2 }
        $body = @{ reason = $A4 }
        Invoke-Flnk -Method POST -Path "/api/projects/$A1/work-items/$A2/agent-run/$A3/block" -Body $body | ConvertTo-Json -Depth 10
    }
    default {
        Write-Error "Unknown command '$Command'. See script header for usage."
        exit 2
    }
}
