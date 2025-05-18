param ( [Parameter(Mandatory=$true)] [string]$PluginAssemblyName)
function Test-VersionNumber ([PSCustomObject]$latestEntry, [PsCustomObject]$newEntry){
    $latestVersion = $latestEntry.AssemblyVersion -split "\."
    $newVersion = $newEntry.AssemblyVersion -split "\."

    if ($latestVersion.Count -ne $newVersion.Count){
        throw "Invalid release version";
    }
    for ($i = 0; $i -lt $latestVersion.Count; $i++){
        # new version is higher: it's good. It's lower? It's incorrect. It's the same? Continue.
        if ([int]$newVersion[$i] -gt [int]$latestVersion[$i]){
            return true;
        }
        if ([int]$newVersion[$i] -lt [int]$latestVersion[$i]){
            throw "New release version number is lower than the latest release"
        }
    }

    # The versions are the same. Test if you're just moving it to release
    if ([int]$newVersion[3] -eq [int]$newVersion[3])
    {
        if($latestEntry.IsTest -eq $true -and $newEntry.IsTest -eq $false){
            # It's moving a test to release without changing
            return true;
        }

        throw "New release version number is the exact same as the latest release"
    }
}

$pluginAssesmblyName = $PluginAssemblyName
$basePluginFolderPath = "$pluginAssesmblyName\"

$schemaPath = "$($basePluginFolderPath)newReleaseSchema.json"
$newestReleasePath = "$($basePluginFolderPath)NewestRelease.json"
Invoke-WebRequest -Uri https://raw.githubusercontent.com/Pistachio-dev/Workflows/refs/heads/master/Schemas/NewestReleaseSchema.json -OutFile $schemaPath -RetryIntervalSec 20 -MaximumRetryCount 10
$newReleaseSchemaString = Get-Content -Path $schemaPath -Raw
$newReleaseDataString = Get-Content -Path $newestReleasePath -Raw

$valid = Test-Json -Json $newReleaseDataString -Schema $newReleaseSchemaString
$valid | Write-Output
"-----------" | Write-Output
if ($valid -ne $true) {
    throw "New release file does not match schema";
}

"New release data is valid" | Write-Output

# Create changelog if it does not exist
$changeLogPath = "$($basePluginFolderPath)ChangeLog.json";
$changeLog = @();
if ((Test-Path $changeLogPath) -and (Get-Content -Path $changeLogPath -Raw).Length -ge 1){
    $changeLog = Get-Content $changeLogPath -Raw | ConvertFrom-Json
}

# Add the new entry to the change log
$newReleaseDataAsJson = Get-Content -Path $newestReleasePath -Raw
$newReleaseData = ConvertFrom-Json -InputObject $newReleaseDataAsJson

if ($changeLog.Count -gt 0){
    $lastEntry = $changeLog[0];
    if (Test-VersionNumber $lastEntry $newReleaseData){
        Write-Output "Version number verified: " + $newReleaseData.AssemblyVersion
    }
}

Write-Output "Adding new release to history file"
$changeLog= @($newReleaseData) + $changeLog
Set-Content -Path $changeLogPath -Value (ConvertTo-JSON -InputObject $Changelog)

$repoPath = "Repo.json";
$basePluginDefinitionJsonPath = "$($basePluginFolderPath)\$($pluginAssesmblyName).json"
if ((Test-Path $repoPath) -eq $false){
    $basePluginData = Get-Content $basePluginDefinitionJsonPath -Raw | ConvertFrom-Json
    $repoData = @($basePluginData)

    Set-Content -Path $repoPath -Value (ConvertTo-Json -InputObject @($repoData))
}

$repoArray = Get-Content -Path $repoPath | ConvertFrom-Json
$repoObject = $repoArray | Select-Object -Index 0
if ($newReleaseData.IsTest){
    $repoObject | Add-Member -NotePropertyName "TestingDalamudApiLevel" -NotePropertyValue $newReleaseData.DalamudApiLevel -Force
    $repoObject | Add-Member -NotePropertyName "TestingAssemblyVersion" -NotePropertyValue $newReleaseData.AssemblyVersion -Force
    $repoObject | Add-Member -NotePropertyName "TestingChangelog" -NotePropertyValue $newReleaseData.ChangeLog -Force
    Write-Output "DalamudApiLevel, AssemblyVersion and Changelog updated for Test"
}
else{
    $repoObject | Add-Member -NotePropertyName "DalamudApiLevel" -NotePropertyValue $newReleaseData.DalamudApiLevel -Force
    $repoObject | Add-Member -NotePropertyName "AssemblyVersion" -NotePropertyValue $newReleaseData.AssemblyVersion -Force
    $repoObject | Add-Member -NotePropertyName "Changelog" -NotePropertyValue $newReleaseData.ChangeLog -Force
    Write-Output "DalamudApiLevel, AssemblyVersion and Changelog updated for Release"
}

Set-Content -Path $repoPath -Value (ConvertTo-Json -InputObject @($repoArray))

Write-Output "Updating .csproj version"

function Set-VersionEntry($xml, [string]$labelName, [string]$newVersion){
    $nodes = $xml.SelectNodes("//Project/PropertyGroup/$($labelName)");
    if ($nodes.Count -eq 0) {
        Write-Warning "Csproj file has no $($labelName) attribute. Consider adding it."
        return;
    }
    if ($nodes.Count -gt 1){
        Write-Warning "There is more than one match for $($labelName)! This should not be happening."
        return;
    }

    $nodes[0].InnerXml = $newVersion;
}

$csprojRoute = "$($basePluginFolderPath)\$($pluginAssesmblyName).csproj";
$xml = [System.Xml.XmlDocument]::new()
$xml.PreserveWhitespace = $true
$xml.Load($csprojRoute)
Set-VersionEntry $xml "FileVersion" $version;
Set-VersionEntry $xml "AssemblyVersion" $version;
$xml.Save([string]$csprojRoute)


Write-Output "Job complete"

