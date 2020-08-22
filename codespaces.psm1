$script:tempDir = [System.IO.Path]::GetTempPath()
$script:codespacesLoc = [System.IO.Path]::Combine($script:tempDir, "codespaces", "bin", "codespaces")

function Start-Codespaces {
    param(
        [Parameter(Position=0, Mandatory)]
        [string]$Subscription,
        [Parameter(Position=1, Mandatory)]
        [string]$ResourceGroup,
        [Parameter(Position=2, Mandatory)]
        [string]$Plan,
        [Parameter(Position=3, Mandatory)]
        [string]$ArmToken,
        [Parameter(Position=4)]
        [string]$SessionName,
        [switch]$Wait
    )

    Write-Host "$(Get-TimeStamp) Stop any active Codespaces instances"
    Stop-Codespaces $ArmToken

    Install-Codespaces $script:tempDir

    $env:VSCS_ARM_TOKEN=$ArmToken

    Write-Host "$(Get-TimeStamp) Starting codespaces session"
    $curDir = Get-Location
    $csJob = Start-Job -ScriptBlock {
        Set-Location $using:curDir
        $codespacesExec = $using:codespacesLoc
        $subscription = $using:Subscription
        $plan = $using:Plan
        $resourceGroup = $using:ResourceGroup
        $sessionName = $using:SessionName
        ("n`n" + $sessionName + "`n") | & $script:codespacesExec start -s $subscription -p $plan -r $resourceGroup
    }

    while ($true) {
        $output = Receive-Job $csJob
        if($output.length -gt 0){
            if($output -match '\[!ERROR\]'){
                Write-Host $output
                return;
            }
            if($output -match 'online.visualstudio.com'){
                $url = $output.substring($output.IndexOf("https"))
                Write-Host "$(Get-TimeStamp) pid: $pid, Connect: $url"
                break;
            }
        }
    }

    if ($Wait) {
        Write-Host "$(Get-TimeStamp) Waiting for debugger to attach"
        Enable-RunspaceDebug -BreakAll
        while (-not $host.Runspace.debugger.IsActive) {

            Write-Host "$(Get-TimeStamp) pid: $pid, Connect: $url"
            Start-Sleep 3
        };
    }
}

function Stop-Codespaces{
    param(
        [Parameter(Position=0, Mandatory)]
        [string]$ArmToken
    )
    $env:VSCS_ARM_TOKEN=$ArmToken
    $codespacesBin = [System.IO.Path]::Combine($script:tempDir, "codespaces", "bin")
    if(Test-Path $codespacesBin){
        $output = & $script:codespacesLoc stop
        if($output -match "!ERROR"){
            Write-Host "$(Get-TimeStamp) No active Codespaces session found"
        }
        else{
            Write-Host "$(Get-TimeStamp) Removed previously active Codespaces session."
        }
    }
}

function Install-Codespaces{
    param(
        [Parameter(Position=0, Mandatory)]
        [string]$BinParentDir
    )

    $global:ProgressPreference = "SilentlyContinue"
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"
    $PSDefaultParameterValues['*:ErrorAction'] = 'Stop'

    if ($null -ne (Get-Process -Name "vsls-agent" -ea "SilentlyContinue")){
        Write-Host "$(Get-TimeStamp) Ending vsls-agent that was still active from a previous session"
        $id = (Get-Process -Name "vsls-agent").Id
        Stop-Process -Id $id
        Wait-Process -Id $id
        Start-Sleep 3
    }

    if(Test-Path (Join-Path $BinParentDir "codespaces")){
        Write-Host "$(Get-TimeStamp) Codespaces folder already exists at $BinParentDir. Deleting and reinstalling."
        Remove-Item (Join-Path $BinParentDir "codespaces") -force -recurse
    }

    New-Item -Path $BinParentDir -Name "codespaces" -ItemType "directory" | Out-Null
    New-Item -Path (Join-Path $BinParentDir "codespaces") -Name "bin" -ItemType "directory" | Out-Null

    $destination = [System.IO.Path]::Combine($BinParentDir, "codespaces", "bin")
    $webClient = New-Object System.Net.WebClient
    switch ($true) {
        ($PSVersionTable.PSVersion.Major -lt 6) {
            # Must be PowerShell Core on Windows
            Import-Module -Name "Microsoft.PowerShell.Archive"
           # $source = "https://vsoagentdownloads.blob.core.windows.net/vsoagent/VSOAgent_win_3958053.zip"
            $source = "https://github.com/justinytchen/test-module/raw/working/VSOAgent_win_3997490.zip"
            $tempdestination = New-Item "codespaces.zip"
            Write-Host "$(Get-TimeStamp) Downloading zip file (Windows)"
            $WebClient.DownloadFile($source, $tempdestination)


            # TEMP FIX
            $tempdestination = "VSOAgent_win_3997490.zip"
            Write-Host "$(Get-TimeStamp) Extracting from zip file"
            Expand-Archive -Path $tempdestination -Destination $destination -Force
            break
        }
        $IsMacOS {
            $tempdestination = New-TemporaryFile
            Import-Module -Name "Microsoft.PowerShell.Archive"
#            $source = "https://vsoagentdownloads.blob.core.windows.net/vsoagent/VSOAgent_osx_3958053.zip";
            $source = "https://github.com/justinytchen/test-module/raw/working/VSOAgent_osx_3997490.zip"
            Write-Host "$(Get-TimeStamp) Downloading zip file (MacOS)"
            $WebClient.DownloadFile($source, $tempdestination)

            # TEMP FIX
            # $tempdestination = "VSOAgent_osx_3997490.zip"
            Write-Host "$(Get-TimeStamp) Extracting from zip file"
            Expand-Archive -Path $tempdestination -Destination $destination -Force
            chmod -R +x [System.IO.Path]::Combine($script:tempDir, "codespaces", "bin")
            break
        }
        $IsLinux {
            $tempdestination = New-TemporaryFile
            # $source = "https://vsoagentdownloads.blob.core.windows.net/vsoagent/VSOAgent_linux_3958053.tar.gz"
            $source = "https://github.com/justinytchen/test-module/raw/working/VSOAgent_linux_3997490.tar.gz"
            Write-Host "$(Get-TimeStamp) Downloading tar.gz file (Linux)"
            $WebClient.DownloadFile($source, $tempdestination)

            # TEMP FIX
            # $tempdestination = "VSOAgent_linux_3997490.tar.gz"
            Write-Host "$(Get-TimeStamp) Extracting from tar.gz file"
            tar -xf $tempdestination -C $destination
            break
        }
        Default {
            $tempdestination = New-TemporaryFile
            # Must be PowerShell Core on Windows
            Import-Module -Name "Microsoft.PowerShell.Archive"
            # $source = "https://vsoagentdownloads.blob.core.windows.net/vsoagent/VSOAgent_win_3958053.zip"
            $source = "https://github.com/justinytchen/test-module/raw/working/VSOAgent_win_3997490.zip"

            Write-Host "$(Get-TimeStamp) Downloading zip file (Windows)"
            $WebClient.DownloadFile($source, $tempdestination)
            Write-Host "$(Get-TimeStamp) Extracting from zip file"

            # TEMP FIX
            # $tempdestination = "VSOAgent_win_3997490.zip"
            Expand-Archive -Path $tempdestination -Destination $destination -Force
            break
        }
    }

    Remove-Item $tempdestination
    Write-Host "$(Get-TimeStamp) Done installing codespaces"
}

function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}