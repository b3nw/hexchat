param ([string] $templateFilename, [string] $outputFilename)

# Copy CFFI backend for Python plugin before building installer
try {
	Write-Host "=== CFFI Backend Copy for Installer ==="

	# Ensure cffi is installed in the build Python
	python -m pip install cffi --upgrade

	# Find the actual CFFI backend file
	$ffiPath = python -c "import sysconfig, os; print(os.path.join(sysconfig.get_paths()['platlib'], '_cffi_backend.cp313-win_amd64.pyd'))"

	if (Test-Path $ffiPath) {
		Write-Host "Found CFFI backend: $ffiPath"

		# Get the destination directory (same as SourceDir in hexchat.iss.tt)
		$relDir = Join-Path (Split-Path -Parent $outputFilename) "..\rel"
		if (!(Test-Path $relDir)) {
			New-Item -ItemType Directory -Path $relDir -Force | Out-Null
		}

		Copy-Item $ffiPath $relDir -Force
		Write-Host "Copied CFFI backend to: $relDir"

		# Verify it's there
		$copiedFiles = Get-ChildItem -Path $relDir -Name "_cffi_backend*.pyd" -ErrorAction SilentlyContinue
		if ($copiedFiles) {
			Write-Host "SUCCESS: CFFI backend files ready for installer: $copiedFiles"
		} else {
			Write-Host "WARNING: CFFI backend copy may have failed"
		}
	} else {
		Write-Host "ERROR: CFFI backend not found at expected path: $ffiPath"

		# Fallback search
		$searchPaths = @(
			"$env:USERPROFILE\AppData\Local\Programs\Python\Python313\Lib\site-packages",
			(python -c "import sysconfig; print(sysconfig.get_paths()['platlib'])")
		)

		$found = $false
		foreach ($path in $searchPaths) {
			if (Test-Path $path) {
				$files = Get-ChildItem -Path $path -Filter "_cffi_backend*.pyd" -ErrorAction SilentlyContinue
				if ($files) {
					$files | ForEach-Object {
						$relDir = Join-Path (Split-Path -Parent $outputFilename) "..\rel"
						if (!(Test-Path $relDir)) {
							New-Item -ItemType Directory -Path $relDir -Force | Out-Null
						}
						Copy-Item $_.FullName $relDir -Force
						Write-Host "Copied fallback CFFI backend: $($_.FullName)"
						$found = $true
					}
				}
			}
		}

		if (-not $found) {
			Write-Host "ERROR: No CFFI backend files found for installer!"
		}
	}
} catch {
	Write-Host "WARNING: CFFI backend copy failed: $($_.Exception.Message)"
}

# Original template processing
$versionParts = Select-String -Path "${env:SOLUTIONDIR}meson.build" -Pattern "  version: '([^']+)',$" | Select-Object -First 1 | %{ $_.Matches[0].Groups[1].Value.Split('.') }

[string[]] $contents = Get-Content $templateFilename -Encoding UTF8 | %{
	while ($_ -match '^(.*?)<#=(.*?)#>(.*?)$') {
		$_ = $Matches[1] + $(Invoke-Expression $Matches[2]) + $Matches[3]
	}
	$_
}

[System.IO.File]::WriteAllLines($outputFilename, $contents)
