<#
.SYNOPSIS
  SeedRover Servo & Mechanism Hardware Tester
  Communicates with the ESP32 via HTTP API.
#>

param(
    [string]$RoverIp = "192.168.4.1",
    [string]$Token = ""
)

# Try reading ROVER_TOKEN from firmware/esp32_seedrover/secrets.h if not provided
if ([string]::IsNullOrWhiteSpace($Token)) {
    $secretsPath = Join-Path $PSScriptRoot "firmware\esp32_seedrover\secrets.h"
    if (Test-Path $secretsPath) {
        $content = Get-Content $secretsPath -Raw
        if ($content -match 'ROVER_TOKEN\s*=\s*"([^"]+)"') {
            $Token = $matches[1]
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    $Token = "HLjHgNQoRsD1gqsBgF2zptRZXOXrVr-VqCfqZqQOjSA"
}

$baseUrl = "http://$RoverIp"

function Send-RoverCommand {
    param(
        [string]$Command,
        [hashtable]$Payload = $null
    )

    $headers = @{
        "Content-Type"  = "application/json"
        "X-Rover-Token" = $Token
    }

    $bodyObj = @{
        "command" = $Command
    }
    if ($Payload) {
        $bodyObj["payload"] = $Payload
    }
    $body = $bodyObj | ConvertTo-Json -Compress

    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/command" -Method Post -Headers $headers -Body $body -TimeoutSec 4
        return $response
    }
    catch {
        Write-Host "  [ERROR] Request failed: $_" -ForegroundColor Red
        return $null
    }
}

function Show-Header {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "         SeedRover Servo & Mechanism Hardware Tester       " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "Target Rover: $baseUrl" -ForegroundColor White
    Write-Host "Token       : $Token" -ForegroundColor Gray
    Write-Host "Pins: Gate 1 = GPIO 27 | Gate 2 = GPIO 4 | Gate 3 = GPIO 23" -ForegroundColor Green
    Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
}

function Test-SingleGate {
    param([int]$GateNum, [string]$CropName, [int]$GpioPin)
    Write-Host "`n--> Testing Gate $GateNum ($CropName on GPIO $GpioPin)..." -ForegroundColor Yellow
    
    $openCmd = "SEED_GATE_${GateNum}_OPEN"
    Write-Host "  Sending $openCmd (Angle 90 deg)..." -ForegroundColor Cyan
    $res1 = Send-RoverCommand -Command $openCmd
    if ($res1) { Write-Host "  Gate $GateNum OPENED." -ForegroundColor Green }
    
    Start-Sleep -Milliseconds 1200
    
    Write-Host "  Sending SEED_GATE_CLOSE (Angle 150 deg)..." -ForegroundColor Cyan
    $res2 = Send-RoverCommand -Command "SEED_GATE_CLOSE"
    if ($res2) { Write-Host "  Gate $GateNum CLOSED." -ForegroundColor Green }
}

function Test-DropSequence {
    param([int]$GateNum, [string]$CropName)
    Write-Host "`n--> Simulating Full Planting Station Drop for Gate $GateNum ($CropName)..." -ForegroundColor Yellow
    
    Write-Host "  1. Lowering hole punch tube (GPIO 2)..." -ForegroundColor Cyan
    Send-RoverCommand -Command "SEED_TUBE_DOWN" | Out-Null
    Start-Sleep -Milliseconds 500

    Write-Host "  2. Opening Seed Gate $GateNum..." -ForegroundColor Cyan
    Send-RoverCommand -Command "SEED_GATE_${GateNum}_OPEN" | Out-Null
    Start-Sleep -Milliseconds 300

    Write-Host "  3. Fast closing Seed Gate..." -ForegroundColor Cyan
    Send-RoverCommand -Command "SEED_GATE_CLOSE" | Out-Null
    Start-Sleep -Milliseconds 200

    Write-Host "  4. Raising hole punch tube (GPIO 2)..." -ForegroundColor Cyan
    Send-RoverCommand -Command "SEED_TUBE_UP" | Out-Null
    Start-Sleep -Milliseconds 400

    Write-Host "  Station drop sequence finished!" -ForegroundColor Green
}

# Ping test
Write-Host "Checking connection to $baseUrl/health..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get -Headers @{"X-Rover-Token" = $Token} -TimeoutSec 3
    Write-Host "Connected! Rover: $($health.data.rover) | FW: $($health.data.firmware_version) | State: $($health.data.planting_state)" -ForegroundColor Green
    Start-Sleep -Seconds 1
} catch {
    Write-Host "Warning: Could not connect to $baseUrl directly." -ForegroundColor DarkYellow
    Write-Host "Make sure your PC/phone is connected to the 'SeedRover-01' Wi-Fi hotspot!" -ForegroundColor DarkYellow
    Start-Sleep -Seconds 2
}

while ($true) {
    Show-Header
    Write-Host "Select an action:" -ForegroundColor White
    Write-Host " [1] Test Gate 1 (Calamansi - GPIO 27)"
    Write-Host " [2] Test Gate 2 (Sitaw - GPIO 4)"
    Write-Host " [3] Test Gate 3 (Peanut - GPIO 23)"
    Write-Host " [4] Test All 3 Gates in Sequence (1 -> 2 -> 3)"
    Write-Host " [5] Test Hole Punch / Seed Tube (GPIO 2)"
    Write-Host " [6] Full Station Drop Sequence (Tube Down -> Gate Open -> Close -> Tube Up)"
    Write-Host " [7] Force Close All Gates"
    Write-Host " [8] Read Sensors & Obstacles"
    Write-Host " [9] Change Target Rover IP"
    Write-Host " [0] Exit"
    Write-Host ""
    $choice = Read-Host "Enter option [0-9]"

    switch ($choice) {
        "1" { Test-SingleGate -GateNum 1 -CropName "Calamansi" -GpioPin 27 }
        "2" { Test-SingleGate -GateNum 2 -CropName "Sitaw" -GpioPin 4 }
        "3" { Test-SingleGate -GateNum 3 -CropName "Peanut" -GpioPin 23 }
        "4" {
            Test-SingleGate -GateNum 1 -CropName "Calamansi" -GpioPin 27
            Start-Sleep -Milliseconds 500
            Test-SingleGate -GateNum 2 -CropName "Sitaw" -GpioPin 4
            Start-Sleep -Milliseconds 500
            Test-SingleGate -GateNum 3 -CropName "Peanut" -GpioPin 23
        }
        "5" {
            Write-Host "`n--> Lowering Seed Drop Tube (GPIO 2)..." -ForegroundColor Yellow
            Send-RoverCommand -Command "SEED_TUBE_DOWN" | Out-Null
            Start-Sleep -Milliseconds 1200
            Write-Host "--> Raising Seed Drop Tube (GPIO 2)..." -ForegroundColor Yellow
            Send-RoverCommand -Command "SEED_TUBE_UP" | Out-Null
            Write-Host "Seed tube test completed." -ForegroundColor Green
        }
        "6" {
            Write-Host "`nWhich gate to drop for?"
            Write-Host " 1: Calamansi (GPIO 27)"
            Write-Host " 2: Sitaw (GPIO 4)"
            Write-Host " 3: Peanut (GPIO 23)"
            $g = Read-Host "Choose gate [1-3]"
            if ($g -in @("1","2","3")) {
                $names = @{"1"="Calamansi"; "2"="Sitaw"; "3"="Peanut"}
                Test-DropSequence -GateNum [int]$g -CropName $names[$g]
            }
        }
        "7" {
            Write-Host "`n--> Closing all gates..." -ForegroundColor Yellow
            Send-RoverCommand -Command "SEED_GATE_CLOSE" | Out-Null
            Write-Host "All seed gates closed." -ForegroundColor Green
        }
        "8" {
            Write-Host "`n--> Fetching sensor snapshot..." -ForegroundColor Yellow
            try {
                $sensors = Invoke-RestMethod -Uri "$baseUrl/sensors" -Method Get -Headers @{"X-Rover-Token" = $Token} -TimeoutSec 3
                Write-Host "  Soil Raw       : $($sensors.data.soil_raw)" -ForegroundColor Cyan
                Write-Host "  Soil Moisture  : $($sensors.data.soil_moisture_percent)%" -ForegroundColor Cyan
                Write-Host "  Soil Temp      : $($sensors.data.soil_temperature_c) C" -ForegroundColor Cyan
                Write-Host "  Air Temp       : $($sensors.data.air_temperature_c) C" -ForegroundColor Cyan
                Write-Host "  Humidity       : $($sensors.data.humidity_percent)%" -ForegroundColor Cyan
                Write-Host "  Front Distance : $($sensors.data.front_distance_cm) cm" -ForegroundColor Cyan
                Write-Host "  Rear Distance  : $($sensors.data.rear_distance_cm) cm" -ForegroundColor Cyan
            } catch {
                Write-Host "Failed to query /sensors: $_" -ForegroundColor Red
            }
        }
        "9" {
            $newIp = Read-Host "Enter new IP address (e.g. 192.168.4.1 or your local router IP)"
            if (-not [string]::IsNullOrWhiteSpace($newIp)) {
                $RoverIp = $newIp
                $baseUrl = "http://$RoverIp"
            }
        }
        "0" {
            Write-Host "`nExiting tester." -ForegroundColor Green
            exit
        }
        default {
            Write-Host "Invalid option." -ForegroundColor Red
        }
    }

    Write-Host ""
    Read-Host "Press Enter to return to menu..."
}
