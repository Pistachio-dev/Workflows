param ( [Parameter(Mandatory=$true)] [string]$PluginAssemblyName)

$basePluginFolderPath = "$PluginAssemblyName\"
$newestReleasePath = "$($basePluginFolderPath)NewestRelease.json"

$newestReleaseData = Get-Content $newestReleasePath | ConvertFrom-Json

$stringedVersion = "$($newestReleaseData.AssemblyVersion)"
if ($newestReleaseData.IsTest){
    return "$($stringedVersion)_testing";
}

return "$($stringedVersion)_release";