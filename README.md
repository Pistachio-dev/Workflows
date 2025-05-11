NewestRelease.json must exist in the same folder as the plugin .csproj file.

ManualRelease.yml uses it to validate and create a release of the plugin. Some variables at its start must be customized per plugin, namely, "assemblyName" and, if publishing to another repository, "target_repo" and "token". The other variables are set by the script later.