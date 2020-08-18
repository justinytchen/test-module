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
        [switch]$NoWait
    )

    $curLoc = Get-Location
    $binFolderName = "codespacesBin"
    Install-Codespaces $curLoc $binFolderName

    Write-Host "Looking for active sessions to stop"
    Try {
        & (Join-Path $curLoc $binFolderName "codespaces") stop
        Write-Host "Stopped a previously active session"
    }
    Catch {
        Write-Host "No active sessions"
    }

    $env:VSCS_ARM_TOKEN=$ArmToken

    Write-Host "Starting job to start codespaces session"
    $csJob = Start-Job -ScriptBlock {
        $subscription = $using:Subscription
        $plan = $using:Plan
        $resourceGroup = $using:ResourceGroup
        $curLoc = $using:curLoc
        $binFolderName = $using:binFolderName
        "n`n`n" | & (Join-Path $curLoc $binFolderName "codespaces") start -s $subscription -p $plan -r $resourceGroup
        # "n`n1`n`n" | & (Join-Path $curLoc $binFolderName "codespaces") start -s $subscription -p $plan
        $env:VSCS_ARM_TOKEN=""
    }

    while ($true) {
        $output = Receive-Job $csJob
        Write-Host $output
        if($output.length -gt 0){
            if($output -match '\[!ERROR\]'){
                # Write-Host $output
                return;
            }
            if($output -match 'online.visualstudio.com'){
                # Write-Host $output
                break;
            }
        }
    }

    if (-not $NoWait) {
        Write-Host "Waiting for debugger to attach"
        while (-not (get-runspace -id 1).debugger.IsActive) {

            Write-Host $output
            Start-Sleep 3
        };
    }
}

function Install-Codespaces{
    param(
        [Parameter(Position=0, Mandatory)]
        [string]$BinParentDir,
        [Parameter(Position=1, Mandatory)]
        [string]$BinFolderName
    )

    $global:ProgressPreference = "SilentlyContinue"
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"
    $PSDefaultParameterValues['*:ErrorAction'] = 'Stop'

    if ($null -ne (Get-Process -Name "vsls-agent" -ea "SilentlyContinue")){
        Write-Host "Ending vsls-agent that was still active from a previous session"
        $id = (Get-Process -Name "vsls-agent").Id
        Stop-Process -Id $id
        Wait-Process -Id $id
        Start-Sleep 3
    }

    if(Test-Path $BinFolderName){
        Write-Host "$BinFolderName folder already exists. Deleting and reinstalling."
        Remove-Item $BinFolderName -force -recurse
    }

    New-Item -Path $BinParentDir -Name $BinFolderName -ItemType "directory"

    $destination = Join-Path $BinParentDir $BinFolderName
    $tempdestination = New-TemporaryFile
    $webClient = New-Object System.Net.WebClient
    switch ($true) {
        ($PSVersionTable.PSVersion.Major -lt 6) {
            # Must be PowerShell Core on Windows
            Import-Module -Name "Microsoft.PowerShell.Archive"
            $source = "https://vsoagentdownloads.blob.core.windows.net/vsoagent/VSOAgent_win_3934786.zip"

            Write-Host "Downloading zip file (Windows)"
            $WebClient.DownloadFile($source, $tempdestination)
            Write-Host "Extracting from zip file"

            Expand-Archive -Path $tempdestination -Destination $destination -Force
            break
        }
        $IsMacOS {
            Import-Module -Name "Microsoft.PowerShell.Archive"
            $source = "https://vsoagentdownloads.blob.core.windows.net/vsoagent/VSOAgent_osx_3920504.zip";

            Write-Host "Downloading zip file (MacOS)"
            $WebClient.DownloadFile($source, $tempdestination)
            Write-Host "Extracting from zip file"

            Expand-Archive -Path $tempdestination -Destination $destination -Force
            chmod -R +x ./bin
            break
        }
        $IsLinux {
            $source = "https://vsoagentdownloads.blob.core.windows.net/vsoagent/VSOAgent_linux_3929085.tar.gz"
            Write-Host "Downloading tar.gz file (Linux)"
            $WebClient.DownloadFile($source, $tempdestination)
            Write-Host "Extracting from tar.gz file"
            tar -xf $tempdestination -C $destination
            break
        }
        Default {
            # Must be PowerShell Core on Windows
            Import-Module -Name "Microsoft.PowerShell.Archive"
            $source = "https://vsoagentdownloads.blob.core.windows.net/vsoagent/VSOAgent_win_3934786.zip"

            Write-Host "Downloading zip file (Windows)"
            $WebClient.DownloadFile($source, $tempdestination)
            Write-Host "Extracting from zip file"

            Expand-Archive -Path $tempdestination -Destination $destination -Force
            break
        }
    }

    Remove-Item $tempdestination
    Write-Host "Done installing codespaces"
}
