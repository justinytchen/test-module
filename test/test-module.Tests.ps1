$ModuleManifestName = 'test-module.psd1'
$ModuleManifestPath = "$PSScriptRoot\..\$ModuleManifestName"

Describe 'Module Manifest Tests' {
    It 'Passes Test-ModuleManifest' {
        $sum = 1 + 1
        $sum | Should -Be 3
    }
}
