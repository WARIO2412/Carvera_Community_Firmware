<#
.SYNOPSIS
Downloads the specified ARM GCC toolchain (if needed) and optionally runs a
command with the toolchain's bin directory added to the PATH.

.DESCRIPTION
This script manages ARM GCC toolchain versions for the project on Windows.
It checks if a specified version (defaulting to 14.2) is present. If not,
it downloads the official toolchain archive, verifies its integrity using
MD5 or SHA256, and unpacks it into the project structure.

It can then either:
- Execute a provided command (and arguments) with the selected toolchain's
  'bin' directory prepended to the PATH environment variable for that process.
- Output a PowerShell command string (using --env) that the calling shell
  can use (via Invoke-Expression) to modify its own PATH.

.PARAMETER GccVersion
Specifies the GCC version to use (e.g., '4.8', '14.2').
Defaults to '14.2'. Supported versions: 4.8, 14.2.

.PARAMETER Env
If specified, the script outputs a PowerShell command string to update the
calling shell's PATH, instead of executing a command.

.PARAMETER Help
Displays this help message and exits.

.PARAMETER CommandToRun
Any remaining arguments after options are treated as the command and its
arguments to be executed with the selected GCC toolchain in the PATH.

.EXAMPLE
# Build using default GCC (14.2)
./build/gcc.ps1 make CNC=1 AXIS=5 PAXIS=3

.EXAMPLE
# Build using GCC 4.8 after running 'make clean'
./build/gcc.ps1 --gcc 4.8 make clean

.EXAMPLE
# Add default GCC (14.2) to the current shell's PATH
Invoke-Expression (& ./build/gcc.ps1 --env)

.EXAMPLE
# Add GCC 4.8 to the current shell's PATH
Invoke-Expression (& ./build/gcc.ps1 --gcc 4.8 --env)

.NOTES
Requires PowerShell 5.1 or later for Expand-Archive and Get-FileHash.
The script assumes it is located in the 'build' directory of the project.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    # --- Standard Named Parameters First ---
    [Parameter(Mandatory=$false)]
    [ValidateSet('4.8', '14.2')]
    [string]$GccVersion = '14.2',

    [Parameter(Mandatory=$false)]
    [switch]$Env,

    [Parameter(Mandatory=$false)]
    [switch]$Help,

    # --- Capture Remaining Arguments Last ---
    [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)]
    [string[]]$CommandToRun
)

# --- Script Setup ---
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue' # Suppress Invoke-WebRequest progress bar

# Get the directory where the script resides and the project root
$ScriptDir = Split-Path -Parent $PSCommandPath # Use PSCommandPath for reliability
$ProjectRoot = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$OriginalPwd = $PWD.Path # Store original working directory

# --- Configuration ---
$DefaultGccVersion = '14.2'
$GccConfigurations = @{
    '4.8' = @{
        DirName      = 'gcc-arm-none-eabi-4.8'
        Url          = 'https://launchpad.net/gcc-arm-embedded/4.8/4.8-2014-q1-update/+download/gcc-arm-none-eabi-4_8-2014q1-20140314-win32.zip'
        Hash         = '09c19b3248863074f5498a88f31bee16'
        HashAlgo     = 'MD5'
        ArchiveName  = 'gcc-arm-none-eabi-4_8-2014q1-20140314-win32.zip'
    }
    '14.2' = @{
        DirName      = 'gcc-arm-none-eabi-14.2'
        Url          = 'https://developer.arm.com/-/media/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-mingw-w64-x86_64-arm-none-eabi.zip'
        Hash         = 'f074615953f76036e9a51b87f6577fdb4ed8e77d3322a6f68214e92e7859888f' # SHA256 hash for the mingw zip
        HashAlgo     = 'SHA256'
        ArchiveName  = 'arm-gnu-toolchain-14.2.rel1-mingw-w64-x86_64-arm-none-eabi.zip'
    }
}

# --- Helper Functions ---

function Show-Help {
    # Get the comment-based help content and display it using the script's path
    Get-Help $PSCommandPath
}

function Verify-FileHash {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string]$ExpectedHash,
        [Parameter(Mandatory=$true)][string]$Algorithm # MD5 or SHA256
    )
    Write-Host "Verifying $Algorithm hash for $(Split-Path $FilePath -Leaf)..."
    try {
        $calculatedHash = (Get-FileHash -Algorithm $Algorithm $FilePath).Hash
        if ($calculatedHash -eq $ExpectedHash) {
            Write-Host "Hash verified successfully."
            return $true
        } else {
            Write-Error "Hash mismatch for $(Split-Path $FilePath -Leaf)! Expected: $ExpectedHash, Calculated: $calculatedHash"
            return $false
        }
    } catch {
        Write-Error "Failed to calculate $Algorithm hash for $FilePath. Error: $($_.Exception.Message)"
        return $false
    }
}

function Download-AndUnpack {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Hash,
        [Parameter(Mandatory=$true)][string]$HashAlgo,
        [Parameter(Mandatory=$true)][string]$TargetDir, # Absolute path to final GCC version directory
        [Parameter(Mandatory=$true)][string]$ArchiveName
    )

    # --- Pre-flight checks ---
    $tempDir = [System.IO.Path]::GetTempPath() # Get platform-agnostic temp path
    if ([string]::IsNullOrEmpty($tempDir)) {
        throw "Could not determine the system temporary path using [System.IO.Path]::GetTempPath()."
    }
    # Ensure the temp directory exists (GetTempPath should return an existing path, but check anyway)
    if (-not (Test-Path $tempDir -PathType Container)) {
         # Maybe try to create it? Let's error out for now, as GetTempPath should point to an existing dir.
         throw "The determined temporary path ('$tempDir') does not exist or is not a directory."
    }
    if ([string]::IsNullOrEmpty($ArchiveName)) {
        throw "Parameter 'ArchiveName' is null or empty. Cannot determine temporary file path."
    }
    # --- End Pre-flight checks ---

    $tempFilePath = Join-Path $tempDir $ArchiveName
    $tempExtractDir = Join-Path $tempDir "$($ArchiveName)-extract" # Temp dir for extraction before stripping component

    try {

        Write-Host "Downloading $ArchiveName from $Url..."
        Invoke-WebRequest -Uri $Url -OutFile $tempFilePath

        if (-not (Test-Path $tempFilePath)) { throw "Temporary file '$tempFilePath' not found after download." }
        if (-not (Verify-FileHash -FilePath $tempFilePath -ExpectedHash $Hash -Algorithm $HashAlgo)) {
            throw "Hash verification failed."
        }

        # Calculate relative path for user message
        $separator = [System.IO.Path]::DirectorySeparatorChar
        $relativeTargetDir = $TargetDir -replace [regex]::Escape($ProjectRoot + $separator), ("." + $separator)

        Write-Host "Unpacking $ArchiveName to $relativeTargetDir..."
        # Ensure target directory exists
        if (-not (Test-Path $TargetDir)) {
            New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
        }
        # Ensure clean temp extraction dir
        if (Test-Path $tempExtractDir) {
            Remove-Item $tempExtractDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $tempExtractDir -Force | Out-Null

        # Unpack to temporary directory first
        Expand-Archive -Path $tempFilePath -DestinationPath $tempExtractDir -Force

        # --- Determine source directory for move --- 
        # Handles both archives with a single top-level dir and archives with content directly at root
        $sourceDirToMove = $null
        $binPathInExtract = Join-Path $tempExtractDir 'bin'

        if (Test-Path $binPathInExtract -PathType Container) {
            # Case 1: bin found directly in extraction root (like GCC 4.8 zip)
            $sourceDirToMove = $tempExtractDir
        } else {
            # Case 2: Check for a single top-level directory (like GCC 14.2 zip or tarballs)
            $subItems = Get-ChildItem -Path $tempExtractDir
            if ($null -eq $subItems -or $subItems.Count -ne 1 -or -not $subItems[0].PSIsContainer) {
                 $existingNames = if ($null -ne $subItems) { $subItems.Name -join ', ' } else { 'none' }
                 throw "Archive '$ArchiveName' did not contain the 'bin' directory directly, nor exactly one top-level directory. Cannot determine source path. Contents found: $existingNames"
            }
            $sourceDirToMove = $subItems[0].FullName
        }
        # --- End Determine source directory ---

        # Add extra safety check before using the path
        if ([string]::IsNullOrEmpty($sourceDirToMove)) {
            throw "Failed to determine the source directory path from the extracted archive."
        }

        Write-Host "Moving contents from $sourceDirToMove to $TargetDir..."
        # This works whether $sourceDirToMove is $tempExtractDir or a subdir within it
        # Move contents of the single subdirectory to the final target directory
        Move-Item -Path (Join-Path $sourceDirToMove '*') -Destination $TargetDir -Force

        Write-Host "Successfully downloaded and unpacked $ArchiveName to $relativeTargetDir."

    } catch {
        # More detailed error reporting
        $errMsg = "Operation failed in Download-AndUnpack: $($_.Exception.Message)"
        if ($_.InvocationInfo) {
            $errMsg += " Script: $($_.InvocationInfo.ScriptName), Line: $($_.InvocationInfo.ScriptLineNumber), Position: $($_.InvocationInfo.OffsetInLine)"
            $errMsg += " Command: $($_.InvocationInfo.Line)"
        }
        Write-Error $errMsg
        # Clean up target dir on failure? Maybe not, partial unpack might be useful for debugging.
        if (Test-Path $TargetDir) {
             Write-Warning "Leaving potentially incomplete directory: $TargetDir"
        }
        throw # Re-throw the exception to halt the script
    } finally {
        # Clean up temporary files/dirs
        if (Test-Path $tempFilePath) {
            Write-Verbose "Removing temporary file: $tempFilePath"
            Remove-Item $tempFilePath -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $tempExtractDir) {
             Write-Verbose "Removing temporary extraction directory: $tempExtractDir"
             Remove-Item $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Check-Gcc {
    param(
        [Parameter(Mandatory=$true)][string]$Version # e.g., '4.8'
    )

    if (-not $GccConfigurations.ContainsKey($Version)) {
        throw "Unsupported GCC version requested: $Version. Supported: $($GccConfigurations.Keys -join ', ')"
    }

    $config = $GccConfigurations[$Version]
    $gccDirName = $config.DirName
    $gccPath = Join-Path $ProjectRoot $gccDirName
    $gccBinPath = Join-Path $gccPath "bin"

    # Calculate relative path for messages using the correct separator
    $separator = [System.IO.Path]::DirectorySeparatorChar
    $relativeGccPath = $gccPath -replace [regex]::Escape($ProjectRoot + $separator), ("." + $separator)

    if (-not (Test-Path $gccBinPath)) {
        Write-Host "GCC toolchain version $Version not detected at $relativeGccPath."
        Write-Host "Downloading GCC $Version..."

        # Call download and unpack
        Download-AndUnpack -Url $config.Url -Hash $config.Hash -HashAlgo $config.HashAlgo -TargetDir $gccPath -ArchiveName $config.ArchiveName

        # Verify again after download attempt
        if (-not (Test-Path $gccBinPath)) {
             throw "GCC bin directory still not found after download attempt: $gccBinPath for version $Version"
        }
        Write-Host "GCC version $Version installed successfully to $relativeGccPath."
    } else {
        Write-Host "Found GCC version $Version at $relativeGccPath"
    }

    # Return the absolute path to the bin directory
    # --- Post-install/Verification Checks ---
    $gccExeName = if ($IsWindows) { 'arm-none-eabi-g++.exe' } else { 'arm-none-eabi-g++' }
    $gccToolPath = Join-Path $gccBinPath $gccExeName
    if (-not (Test-Path $gccToolPath -PathType Leaf)) {
        throw "GCC tool '$gccExeName' not found at expected path '$gccToolPath' after installation/check."
    }

    # Check architecture on Unix-like systems
    if ($IsMacOS -or $IsLinux) {
        try {
            $fileOutput = (& file $gccToolPath) -join "`n"
            Write-Host "INFO: GCC executable type: $fileOutput" # Keep this potentially useful info
        } catch {
            Write-Warning "Could not run 'file' command on '$gccToolPath'. Cannot verify architecture. Error: $($_.Exception.Message)"
        }
    }
    # --- End Post-install Checks ---

    return $gccBinPath
}


# --- Main Execution ---

if ($Help) {
    Show-Help
    exit 0
}

# Use the explicitly provided version or the default
$requestedGccVersion = if ($PSBoundParameters.ContainsKey('GccVersion')) { $GccVersion } else { $DefaultGccVersion }

$gccBinPath = $null
try {
    $gccBinPath = Check-Gcc -Version $requestedGccVersion
} catch {
    # Print more details from the caught exception
    Write-Error "Failed to ensure GCC version $requestedGccVersion is available. Error: $($_.Exception.Message)"
    exit 1
}

if (-not $gccBinPath -or -not (Test-Path $gccBinPath -PathType Container)) { # Also check if the path is a valid directory
    Write-Error "Failed to determine or validate GCC bin path ('$gccBinPath') for version $requestedGccVersion."
    exit 1
}

# Output environment modification command if requested
if ($Env) {
    # Output the command to prepend the GCC bin path to the PATH environment variable
    # Use the platform-specific path separator
    $pathSeparator = [System.IO.Path]::PathSeparator
    Write-Output ('$env:PATH="{0}{1}{2}"' -f $gccBinPath, $pathSeparator, $env:PATH)
    exit 0
}

# Check if a command was provided
if ($CommandToRun.Length -eq 0) {
    Write-Error "No command provided to execute."
    Show-Help
    exit 1
}

# Execute the command with the modified PATH
Write-Host "Executing command with GCC $requestedGccVersion in PATH: $($CommandToRun -join ' ')"
$originalPath = $env:PATH
$pathSeparator = [System.IO.Path]::PathSeparator
$env:PATH = "$gccBinPath$pathSeparator$originalPath" # Prepend GCC path using correct separator
$exitCode = 0

try {
    # Execute the command from the original directory
    Set-Location $OriginalPwd
    # Use the call operator '&' and pass arguments individually
    & $CommandToRun[0] $CommandToRun[1..($CommandToRun.Length - 1)]
    $exitCode = $LASTEXITCODE
} catch {
    Write-Error "Command execution failed: $($_.Exception.Message)"
    $exitCode = 1 # Indicate failure
} finally {
    # Restore original PATH
    $env:PATH = $originalPath
    # Return to original location (although Set-Location in try block might fail)
    if ($PWD.Path -ne $OriginalPwd) {
        Set-Location $OriginalPwd -ErrorAction SilentlyContinue
    }
}

exit $exitCode 