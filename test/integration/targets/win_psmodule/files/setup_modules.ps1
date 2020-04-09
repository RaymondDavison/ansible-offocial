$ErrorActionPreference = "Stop"

$template_path = $args[0]
$template_manifest = Join-Path -Path $template_path -ChildPath template.psd1
$template_script = Join-Path -Path $template_path -ChildPath template.psm1
$template_nuspec = Join-Path -Path $template_path -ChildPath template.nuspec
$nuget_exe = Join-Path -Path $template_path -ChildPath nuget.exe

$packages = @(
    @{ name = "ansible-test1"; version = "1.0.0"; repo = "PSRepo 1"; function = "Get-AnsibleTest1" },
    @{ name = "ansible-clobber"; version = "1.0.0"; repo = "PSRepo 1"; function = "Enable-PSTrace" }
)

foreach ($package in $packages) {
    $tmp_dir = Join-Path -Path $template_path -ChildPath $package.name
    if (Test-Path -Path $tmp_dir) {
        Remove-Item -Path $tmp_dir -Force -Recurse
    }
    New-Item -Path $tmp_dir -ItemType Directory > $null

    try {
        $ps_data = ""
        $nuget_version = $package.version

        $manifest = [System.IO.File]::ReadAllText($template_manifest)
        $manifest = $manifest.Replace('--- NAME ---', $package.name).Replace('--- VERSION ---', $package.version)
        $manifest = $manifest.Replace('--- GUID ---', [Guid]::NewGuid()).Replace('--- FUNCTION ---', $package.function)

        $manifest = $manifest.Replace('--- PS_DATA ---', $ps_data)
        $manifest_path = Join-Path -Path $tmp_dir -ChildPath "$($package.name).psd1"
        Set-Content -Path $manifest_path -Value $manifest

        $script = [System.IO.File]::ReadAllText($template_script)
        $script = $script.Replace('--- NAME ---', $package.name).Replace('--- VERSION ---', $package.version)
        $script = $script.Replace('--- REPO ---', $package.repo).Replace('--- FUNCTION ---', $package.function)
        $script_path = Join-Path -Path $tmp_dir -ChildPath "$($package.name).psm1"
        Set-Content -Path $script_path -Value $script

        # We should just be able to use Publish-Module but it fails when running over WinRM for older hosts and become
        # does not fix this. It fails to respond to nuget.exe push errors when it canno find the .nupkg file. We will
        # just manually do that ourselves. This also has the added benefit of being a lot quicker than Publish-Module
        # which seems to take forever to publish the module.
        $nuspec = [System.IO.File]::ReadAllText($template_nuspec)
        $nuspec = $nuspec.Replace('--- NAME ---', $package.name).Replace('--- VERSION ---', $nuget_version)
        $nuspec = $nuspec.Replace('--- FUNCTION ---', $package.function)
        Set-Content -Path (Join-Path -Path $tmp_dir -ChildPath "$($package.name).nuspec") -Value $nuspec

        &$nuget_exe pack "$tmp_dir\$($package.name).nuspec" -outputdirectory $tmp_dir

        $repo_path = Join-Path -Path $template_path -ChildPath $package.repo
        $nupkg_filename = "$($package.name).$($nuget_version).nupkg"
        Copy-Item -Path (Join-Path -Path $tmp_dir -ChildPath $nupkg_filename) `
            -Destination (Join-Path -Path $repo_path -ChildPath $nupkg_filename)
    } finally {
        Remove-Item -Path $tmp_dir -Force -Recurse
    }
}