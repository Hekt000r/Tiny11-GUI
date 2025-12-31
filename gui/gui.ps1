Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Helper to find resources in either flat (Prod) or nested (Dev) structure
function Get-ResourcePath {
    param($fileName, $relativePath)
    
    # 1. Check current directory (Flat/Packaged)
    $flatPath = Join-Path $PSScriptRoot $fileName
    if (Test-Path $flatPath) { return $flatPath }
    
    # 2. Check relative path (Dev)
    $devPath = (Resolve-Path "$PSScriptRoot\$relativePath").Path
    if (Test-Path $devPath) { return $devPath }
    
    return $null
}

# Import Module
$modulePath = Get-ResourcePath "tiny11.psm1" "..\core\tiny11.psm1"
if (-not $modulePath) { throw "Could not find tiny11.psm1 module." }
Import-Module $modulePath

# Load XAML
[xml]$xaml = Get-Content "$PSScriptRoot/MainWindow.xaml"
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Find UI elements
$IsoBox        = $window.FindName("IsoBox")
$BrowseBtn     = $window.FindName("BrowseBtn")
$ScanBtn       = $window.FindName("ScanBtn")
$IndexCombo    = $window.FindName("IndexCombo")
$ScratchBox    = $window.FindName("ScratchBox")
$EdgeCheck     = $window.FindName("EdgeCheck")
$TelemetryCheck= $window.FindName("TelemetryCheck")
$BuildBtn      = $window.FindName("BuildBtn")
$StatusText    = $window.FindName("StatusText")
$ProgressBar   = $window.FindName("ProgressBar")
$LogBox        = $window.FindName("LogBox")

# Synchronized data for cross-thread communication (STATE only, no UI objects)
$sync = [hashtable]::Synchronized(@{
    Percent    = 0
    Status     = "Ready"
    Logs       = [System.Text.StringBuilder]::new()
    IsComplete = $false
    Error      = $null
    TaskRunning = $false
})

# Timer for polling status updates
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(100)
$timer.Add_Tick({
    # Update UI from sync state
    $ProgressBar.Value = $sync.Percent
    $StatusText.Text = $sync.Status
    
    if ($sync.Logs.Length -gt 0) {
        $LogBox.AppendText($sync.Logs.ToString())
        $LogBox.ScrollToEnd()
        $sync.Logs.Clear() 
    }

    if ($sync.IsComplete) {
        $timer.Stop()
        $BuildBtn.IsEnabled = $true
        
        if ($sync.Error) {
             [System.Windows.MessageBox]::Show("Build Failed: $($sync.Error)", "Error", "OK", "Error")
             $StatusText.Text = "Build Failed"
        } else {
             $StatusText.Text = "Build Complete!"
        }
        
        # Cleanup runsapce in background task finally block, so just reset flag
        $sync.TaskRunning = $false
    }
})

# Browse ISO event
$BrowseBtn.Add_Click({
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = "ISO Files (*.iso)|*.iso|All Files (*.*)|*.*"
    $dialog.Title = "Select Windows ISO"
    
    if ($dialog.ShowDialog()) {
        $IsoBox.Text = $dialog.FileName
    }
})

# Scan ISO event
$ScanBtn.Add_Click({
    try {
        $path = $IsoBox.Text
        if (-not $path) { throw "Please enter an ISO path or drive letter first." }
        
        $LogBox.AppendText("Scanning $path...`n")
        $ScanBtn.IsEnabled = $false
        
        $result = Get-Tiny11ImageInfo -IsoPath $path
        
        $IndexCombo.ItemsSource = @($result.Images)
        if ($result.Images.Count -gt 0) {
            $IndexCombo.SelectedIndex = 0
        }
        
        $LogBox.AppendText("Found $($result.Images.Count) image(s).`n")
        $StatusText.Text = "ISO scanned. Edition(s) loaded."
        
        # If it was a file, it's now mounted. The core logic handles remounting during build,
        # but for scanning we might want to keep metadata if we needed it. 
        # Currently the psm1 unmounts on error but leaves it if successful for scanning?
        # Actually psm1 leaves it mounted if it succeeds in Get-Tiny11ImageInfo so the user can see editions.
    }
    catch {
        [System.Windows.MessageBox]::Show("Error: $_", "Scanning Failed", "OK", "Error")
    }
    finally {
        $ScanBtn.IsEnabled = $true
    }
})
# Build event
$BuildBtn.Add_Click({
    try {
        $isoPath = $IsoBox.Text.Trim()
        $scratchDrive = $ScratchBox.Text.Trim()
        $selectedEdition = $IndexCombo.SelectedValue

        if (-not $isoPath) {
            throw "Please select a Windows ISO or drive first."
        }
        if (-not $scratchDrive) {
            throw "Please specify a Scratch Drive letter (e.g., 'C')."
        }
        if (-not $selectedEdition) {
            throw "Please select a Windows edition (click Scan first)."
        }

        $BuildBtn.IsEnabled = $false
        $ProgressBar.Value = 0
        $LogBox.Clear()
        $StatusText.Text = "Starting build..."

        $LogBox.AppendText("Initializing background runspace...`n")

        # Reset sync state
        $sync.Percent = 0
        $sync.Status = "Starting background runspace..."
        $sync.Logs.Clear()
        $sync.IsComplete = $false
        $sync.Error = $null
        $sync.TaskRunning = $true
        
        $LogBox.Clear()
        $timer.Start()

        # Create and open a Runspace explicitly
        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $rs.SessionStateProxy.SetVariable("sync", $sync)

        $ps = [PowerShell]::Create()
        $ps.Runspace = $rs
        
 
        
        # Unblock module as a precaution
        Unblock-File -Path $modulePath -ErrorAction SilentlyContinue

        # Capture values from UI thread to avoid object expansion issues
        # Force strict boolean context to ensure we get "True" or "False", never null/empty
        $removeEdgeVal = ($EdgeCheck.IsChecked -eq $true)
        $telemetryVal = ($TelemetryCheck.IsChecked -eq $true)

        # String-based script that ONLY updates $sync state
        $backgroundScript = @"
            try {
                Import-Module '$modulePath' -ErrorAction Stop
                
                # Determine Output Path (we pass explicit output path or let module handle it?)
                # Actually, let's calculate it here to show user or logic. 
                # The module's new logic handles null, but let's pass null safely.
                
                Build-Tiny11 -IsoPath '$isoPath' -ScratchDrive '$scratchDrive' -ImageIndex $selectedEdition -RemoveEdge `$$removeEdgeVal -DisableTelemetry `$$telemetryVal -OutputPath `$null -OnProgress {
                    param(`$msg, `$pct)
                    `$sync.Percent = `$pct
                    `$sync.Status = `$msg
                    [void]`$sync.Logs.AppendLine("[`$pct%] `$msg")
                }
            }
            catch {
                `$sync.Error = `$_.Exception.Message
                [void]`$sync.Logs.AppendLine("`n[ERROR] `$($_.Exception.Message)")
            }
            finally {
                `$sync.IsComplete = `$true
            }
"@
        
        [void]$ps.AddScript($backgroundScript)

        # Execute async
        $ps.BeginInvoke()
        $LogBox.AppendText("Process launched. Waiting for updates...`n")
    }
    catch {
        $StatusText.Text = "Validation failed!"
        [System.Windows.MessageBox]::Show("Error: $_", "Error", "OK", "Error")
        $BuildBtn.IsEnabled = $true
    }
})

$window.ShowDialog()
