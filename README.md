CloudyProtons's SecureBackup script using GPG.

You will need the following programs installed in order for the script to fully function:
- smartmontools
- file-roller
- tar
- gnupg
- rsync
- coreutils (shred)
- clamav

Place this script on a backup hard drive. For full use, mount in multiple external drives and respond 'y' to the prompts asking to mirror copies to their drive paths. The number of backup archive files to be saved and which folders get archived are configurable in the first lines of the script file. The restoration process refers to these filepaths to automatically replace files, if not, it will prompt you interactively. A full backup or restoration will take some time so be patient and DO NOT forget your encryption password.
