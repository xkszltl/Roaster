Project
================

Roaster is a distribution for open-source project on Windows.
The main goal for us is to support the entire dependency tree of Deep Learning frameworks, like Caffe2/Ort.
It also includes some other libraries as long as we need to use them.

Roaster helps you build dependencies and install system-wide as dynamic libraries.
You can reuse these libraries/tools in other projects.

System Requirement
================

Windows
----------

`Windows 10` or later, 64-bit only.
No plan to support 32-bit platform, and hard-coded architecture path exists in code.

Powershell
----------

`Run as Administrator` is always required because we need to create system files.
Our scripts refuse to run with insufficient permission.
This feature is only available from powershell 4 or later versions.
So get a `Windows 10` please.

Visual Studio
----------

Latest version is preferred.
Currently it's Visual Studio 2017, latest subversion preferred.
Please install all versions of WinSDK and VC toolchains (XP is not needed...).

Git
----------
Install it manually or get it from Visual Studio Installation.
Please ensure to opt in for updating the environment path variable as we leverage several of the tools that are installed along w/git.

CMake
----------

Always get the latest version.

Design
================

Language
----------
On Windows, we write the script in powershell.
Hence no annoying dependencies, like python or compilers, is needed.

We also try to avoid anything related to `cmd` because it's too old.
But for compatibility reason, sometimes we need to bring in `*vars.bat` to setup environment.
In that case we will call `cmd` and steal things back to powershell.

For some speical case not supported by powershell, we will uses `cmd /c`.
Known issues are:
1. Pipe / Redirection. Powershell alternates all data in pipe to use UTF-16.
2. `mklink`. Cmd allows you to create link without admin permission.
3. `rmdir`. There're some cases where powershell doesn't work well.

**Pipe**

Due to the pipe issue, you must use for `curl -o` and `tar -f`.

There's no similar output options for `protoc` (you may need it to alternate neural network models).
In this case wrap it with `cmd /c`.

**Exit Code**

Powershell doesn't have (or I'm not aware of) `set -e` to exit immediately at non-zero exit code.
You'll have to check it with `if (-Not $?)` manually.

Static/Dynamic
----------

Everything in Roaster should be built as dynamic libraries, unless it's not doable or have huge performance impact.
The goal here is to:
1. Reduce downstream build time.
2. Provide ABI compatibility, especially for STL and CRT. We uses several different dev/prod environments. There was even a mix of vc140/vc141.
3. Provide LTO (i.e. `/GL` and `/LTCG`) compatibility.

Many open-source project are created for Linux and gcc, and lack of Windows support, especially for DLL because:
1. MSVC hide symbols while gcc/clang exports everything by default.
2. In the gcc world, visibility is enough. For MSVC, there's difference between `dllimport` and `dllexport`.

If you get into any trouble, don't be surprised.
You can typically resolve it in the following way:
1. Patch symbols with proper decoration, and submit PR to upstream.
2. The evil way, `CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS`. It won't always work.

Version
----------

Usually we checkout the latest release from source code repo.
For certain libraries without proper release cycle, or has very important patches in `master`, it also makes sense to build from `master`.

For `git` repo, we try to avoid statically bind to any specific version.
Instead the latest release is detected by regex and only that commit is cloned to save network traffic.

Patch
----------

PR to the official repo is always preferred.
When PR process is too slow or impossible, to Google for example, try the following suggestions:

1. Some bugs, especially DLL related issues, might be bypassed by turning the build arguments.
2. When you really have to patch the source code, use regex for small dirty fixes. This may last longer than `git merge`.
3. For big fixes or pending PR, use a fork repo to hold private commits and use `git pull <patch repo> <PR branch>` after `git clone` from the official one.

Install
----------

We try to put all installed things in there default place if they have one.
Usually it's a directory under `C:/Program Files`.
Then all the `.dll` files will be symlinked to `System32` for convenience.

This approach is less messy comparing to alternating `PATH`, and provides version uniqueness to avoid hidden multi-version bugs.

Uninstall
----------
Since `.dll` in `System32` are symlinks, it's very easy to distinguish them from stock system files.
You can either pick them out manually, or simply delete the original directory to break the link.

Usage
================

Method 1
--------
Run install.ps1 from a Powershell command prompt w/administrative rights.

Method 2
--------
Open a PowerShell (`Run as Administrator` required) and call script for the package you want.

Here's an example:
```
& ${ROASTER_ROOT}/pkgs/caffe2
```

No implicit dependency analysis available. Please call the scripts in the same order as specified
in the installation script "install.ps1"

You can always reinstall/update packages by the same process.

Environment
----------

Take a look in `/env`, there's variables for switching Python or other toolchains.

Set a different `${Env:GIT_MIRROR}` in case you want to use a private repo for faster `git clone`.
Note that this does not affect the submodule URLs.

Issue
================

If you failed to install certain packages, you may still be able to skip them and do the rest.
You can try to debug yourselves since, IMHO, the code is very easy to read.

New issues can pop out as packages get updates.
Please do report those thing so that we can keep the script up-to-date.

Powershell Remove Error
--------
If you see something like:
```
rm : There is a mismatch between the tag specified in the request and the tag present in the reparse point+ rm -Force -Recurse -ErrorAction SilentlyContinue -WarningAction Silen ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Remove-Item], Win32Exception
    + FullyQualifiedErrorId : System.ComponentModel.Win32Exception,Microsoft.PowerShell.Commands.RemoveItemCommand
```
Delete that directory from explorer.
