$id = $pid
Write-Host "pid is $id in TestFile"

# while (-not (get-runspace -id 1).debugger.IsActive) {sleep 1};
Wait-Debugger
$a = 0