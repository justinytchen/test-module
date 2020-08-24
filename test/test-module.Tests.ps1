$ModuleManifestName = 'test-module.psd1'
$ModuleManifestPath = "$PSScriptRoot\..\$ModuleManifestName"

Describe 'Module Manifest Tests' {
    It 'Passes Test-ModuleManifest' {
        $res = 1 + 1
        $res | Should Be 3
    }
}
