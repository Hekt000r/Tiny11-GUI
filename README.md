# Tiny 11 GUI

This is a GUI tool for building your own bloatware-free version of Windows.

### Credits:
Credits to [NTDEV](https://github.com/ntdevlabs) for the [original Tiny11 builder script](https://github.com/ntdevlabs/tiny11builder), which was refactored to be used in this GUI

## How to use

The GUI is very simple.

<img src="https://i.imgur.com/ap2ZD46.png" alt="Screenshot of Tiny11-GUI" height="400">


First, you will need a Windows 11 ISO.
You can use any Windows 11 ISO, but for the cleanest results, i suggest you get a Windows 11 LTSC image from [MASSGRAVE](https://massgrave.dev/windows_ltsc_links)

Then, hit _browse_, select your ISO, and hit "Scan"

After scanning, it will show you the available Windows Editions. (Home, Pro, LTSC, etc.)
Select your preferred edition.

Next, you can choose whether or not to Remove Microsoft Edge and Remove Telemetry.
Note: If you remove Edge there will be no browser by default, so in that case you can download something like [Google Chrome portable](https://portableapps.com/apps/internet/google_chrome_portable) and put it on a USB.

The "Scratch Drive" option is basically where the temporary files will be stored. Most of the time, you can just leave this at the default (C) drive.
**NOTE:** Make sure you have enough free space before continuing (Atleast ~20 GB is preferable.)

Finally, hit "Start building Tiny11" and the build proccess will begin.
Depending on your hardware, it might take 5-30 minutes.

Final install stats (With Windows 11 LTSC Image) + (VMware Tools)
Size: 15.0 GB
Processes: 110 Threads: 1190 Handles: 39315


## What is removed?

**NOTE:** Stuff you might need (Like XBOX app for games) can be re-installed. Windows Update and Windows Defender are still 100% functional, those haven't been touched.

| Item / Change | Type |
| :--- | :--- |
| AppUp.IntelManagementandSecurityStatus | App Removal |
| Clipchamp.Clipchamp | App Removal |
| DolbyLaboratories.DolbyAccess | App Removal |
| DolbyLaboratories.DolbyDigitalPlusDecoderOEM | App Removal |
| Microsoft.BingNews | App Removal |
| Microsoft.BingSearch | App Removal |
| Microsoft.BingWeather | App Removal |
| Microsoft.Copilot | App Removal |
| Microsoft.Windows.CrossDevice | App Removal |
| Microsoft.GamingApp | App Removal |
| Microsoft.GetHelp | App Removal |
| Microsoft.Getstarted | App Removal |
| Microsoft.Microsoft3DViewer | App Removal |
| Microsoft.MicrosoftOfficeHub | App Removal |
| Microsoft.MicrosoftSolitaireCollection | App Removal |
| Microsoft.MicrosoftStickyNotes | App Removal |
| Microsoft.MixedReality.Portal | App Removal |
| Microsoft.MSPaint | App Removal |
| Microsoft.Office.OneNote | App Removal |
| Microsoft.OfficePushNotificationUtility | App Removal |
| Microsoft.OutlookForWindows | App Removal |
| Microsoft.Paint | App Removal |
| Microsoft.People | App Removal |
| Microsoft.PowerAutomateDesktop | App Removal |
| Microsoft.SkypeApp | App Removal |
| Microsoft.StartExperiencesApp | App Removal |
| Microsoft.Todos | App Removal |
| Microsoft.Wallet | App Removal |
| Microsoft.Windows.DevHome | App Removal |
| Microsoft.Windows.Copilot | App Removal |
| Microsoft.Windows.Teams | App Removal |
| Microsoft.WindowsAlarms | App Removal |
| Microsoft.WindowsCamera | App Removal |
| microsoft.windowscommunicationsapps | App Removal |
| Microsoft.WindowsFeedbackHub | App Removal |
| Microsoft.WindowsMaps | App Removal |
| Microsoft.WindowsSoundRecorder | App Removal |
| Microsoft.WindowsTerminal | App Removal |
| Microsoft.Xbox.TCUI | App Removal |
| Microsoft.XboxApp | App Removal |
| Microsoft.XboxGameOverlay | App Removal |
| Microsoft.XboxGamingOverlay | App Removal |
| Microsoft.XboxIdentityProvider | App Removal |
| Microsoft.XboxSpeechToTextOverlay | App Removal |
| Microsoft.YourPhone | App Removal |
| Microsoft.ZuneMusic | App Removal |
| Microsoft.ZuneVideo | App Removal |
| MicrosoftCorporationII.MicrosoftFamily | App Removal |
| MicrosoftCorporationII.QuickAssist | App Removal |
| MSTeams / MicrosoftTeams | App Removal |
| Microsoft.549981C3F5F10 (Cortana) | App Removal |
| Microsoft Edge (Browser, Update, WebView) | File Removal |
| OneDrive (OneDriveSetup.exe) | File Removal |
| BypassCPUCheck | Registry Tweak |
| BypassRAMCheck | Registry Tweak |
| BypassSecureBootCheck | Registry Tweak |
| BypassStorageCheck | Registry Tweak |
| BypassTPMCheck | Registry Tweak |
| AllowUpgradesWithUnsupportedTPMOrCPU | Registry Tweak |
| UnsupportedHardwareNotificationCache | Registry Tweak |
| AllowTelemetry (Disabled) | Registry Tweak |
| AdvertisingInfo (Disabled) | Registry Tweak |
| StartComponentCleanup / ResetBase | System Optimization |
| autounattend.xml integration | Automation |




## Technical Details:

I wanted this to be as simple as possible, so im using WPF + Powershell, making the UI very lightweight and simple.
