[README.md](https://github.com/user-attachments/files/34815423/README.md)
# DroidDesk

DroidDesk is a Windows PowerShell WinForms desktop interface for managing Android apps through ADB and scrcpy.

## Build the Windows EXE with GitHub Actions

1. Create a GitHub repository (for example, `DroidDesk`).
2. Upload the contents of this folder to the repository's **main** branch. Keep the `.github/workflows/build.yml` path intact.
3. Open the repository's **Actions** tab.
4. Select **Build DroidDesk EXE** and choose **Run workflow**, or push a change to `DroidDesk_v1.0.ps1`.
5. When the workflow finishes successfully, open the run and download the `DroidDesk-Windows` artifact. It contains `DroidDesk.exe`.

## Publish a public download

After the workflow file is on the `main` branch:

1. Open the repository's **Releases** page and create a new release.
2. Create a tag named `v1.0.0` and publish the release.
3. The tag push triggers the workflow. When it finishes, `DroidDesk.exe` is attached to that GitHub Release automatically.

## Requirements on the user's PC

The EXE is a wrapper around the PowerShell application; it does not include Android platform tools. Users need to download the complete Windows scrcpy release ZIP from the official Genymobile scrcpy project, extract it, then open DroidDesk's Setup and select `scrcpy.exe` from that extracted folder. DroidDesk looks for `adb.exe` (and optionally `aapt.exe`) in the same folder.

Official scrcpy project: https://github.com/Genymobile/scrcpy

## Notes

- Build runs on GitHub-hosted Windows and produces a Windows EXE.
- The first run may show a Windows SmartScreen warning because the EXE is not code-signed.
- PS2EXE packages the script; it does not encrypt or make the PowerShell source impossible to recover.
- Review the scrcpy and Android platform-tools licenses before redistributing their binaries. This project does not bundle them.
