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

## Technical Details:

I wanted this to be as simple as possible, so im using WPF + Powershell, making the UI very lightweight and simple.
