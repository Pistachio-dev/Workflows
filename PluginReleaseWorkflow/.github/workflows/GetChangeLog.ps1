param ( [Parameter(Mandatory=$true)] [string]$PluginAssemblyName)

$basePluginFolderPath = "$PluginAssemblyName\"
$newestReleasePath = "$($basePluginFolderPath)NewestRelease.json"

$newestReleaseData = Get-Content $newestReleasePath | ConvertFrom-Json

$changeLog = $newestReleaseData.Changelog

return $changeLog