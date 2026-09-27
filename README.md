# Disable Hyper-V in an Alternate Windows Boot Mode

A small, open-source Windows utility that creates a **separate boot entry** with `hypervisorlaunchtype off` and `vsmlaunchtype off`. The regular Windows entry remains unchanged. No reboot is performed automatically.

## Requirements

- Windows 10/11 and administrator approval for changes to boot configuration.
- Access to the BitLocker recovery key **before** editing boot settings: a boot change may trigger recovery.

## Use

1. Download the repository and keep `Run-Service-Boot-Mode.cmd` and `Service-Boot-Mode.ps1` together in one folder.
2. Run `Run-Service-Boot-Mode.cmd`, select **1**, approve UAC, and type `CREATE` when prompted.
3. The utility exports **this computer's** BCD store to `%LOCALAPPDATA%\ServiceBootMode`, clones the current Windows entry, and disables the hypervisor and VSM on the **new entry only**.
4. On restart, choose **Service Mode - Hypervisor Off** from the boot menu, if shown. Otherwise use Windows advanced startup → **Use another operating system** to select it. The utility does not alter the default entry or boot-menu timeout.
5. Select **2** in the launcher and type `REMOVE` to remove only the entry created by this utility. Local backups remain available.

Option **3** runs a no-change preview. You can also run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Service-Boot-Mode.ps1 -DryRun`.

## Important limitations

- Hyper-V, WSL2, VBS/Memory Integrity, and dependent features may not work or may provide less protection **while the alternate entry is selected**. Select the regular entry for normal operation.
- Do not import another computer's `.bcd` backup: BCD stores contain machine-specific configuration. This utility exports a fresh backup locally before creating an entry.
- It does not guarantee compatibility with any third-party application. Test recovery procedures before making boot changes.
- The PowerShell parser and `-DryRun` path were tested. Live BCD modification on other computers has **not** been validated as part of this release.

## License

MIT — see [LICENSE](LICENSE).
