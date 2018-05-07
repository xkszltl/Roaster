Project
================

Roaster is the way you get Caffe2 from scratch.
It helps you build dependencies and install system-wide as dynamic libraries.
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
Currently it's Visual Studio 2017.
Please also install the `v140` toolset and Visual Studio 2015 for CUDA compatibility.

CUDA
----------

Latest version is preferred, unless we encounter some important legacy code in the future.
Current support is CUDA 9.1.
You don't need to get cuDNN your self, we'll have with that.

Python
----------

Python with `pip` is required.
You can get Python 3 from Visual Studio Installation.

Git
----------

Install it manually or get it from Visual Studio Installation.

CMake
----------

Get the latest version, `3.11.1` at least.

Design
================

Language
----------
On Windows, we write the script in powershell.
Hence no annoying dependencies, like python or compilers, is needed.

We also try to avoid anything related to `cmd` because it's too old.
But for compatibility reason, sometimes we need to bring in `*vars.bat` to setup environment.
In that case we will call `cmd` and steal things back to powershell.

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

This approach is less messy comparing to alternating `PATH`, and provides version uniqueness too avoid hidden multi-version bugs.

Uninstall
----------
Since `.dll` in `System32` are symlinks, it's very easy to distinguish them from stock system files.
You can either pick them out manually, or simply deleted the original directory to break the link.

Usage
================

Open a PowerShell (`Run as Administrator` required) and call script for the package you want.

Here's an example:
```
& ${ROASTER_ROOT}/pkgs/caffe2
```

No implicit dependency analysis available.
Please call them in certain order.

You can always reinstall/update packages by the same process.

Order
----------

* Intel libraries [Download first, and link]
* cuDNN
* Boost [Prebuild version from official site should also work]
* Eigen
* MKL-DNN
* GFlags
* GLog
* GTest
* Snappy
* Protobuf
* PyBind
* OpenCV [Skip this please, not ready yet, you can do it yourselves if you want.]
* RocksDB
* Caffe2

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
