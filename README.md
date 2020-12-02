[![build status](/../badges/master/build.svg)](/../commits/master)

Introduction
====================

This project is for scriptizing daily IT work about Linux and Windows.

Linux
----------

Currently we only support CentOS 7 and Ubuntu 18.04 LTS
CentOS 7 is my main working platform but it's also good to enjoy the speed of apt-get.
I may add support for higher version when it comes out.
But there's no plan for supporting earlier versions.

Currently Ubuntu build only enables a subset of features.
This is just due to my use case.
There's no hard limit.

Windows
----------

Everything about Windows is listed under `/win/` currently.
It uses a different infrastructure as Linux.
Will gradually merge them together.

macOS
----------

You guys already have [Homebrew](https://brew.sh/)!

Features
====================

* Docker sandbox
* Bare metal deployment
* Git repositoies mirroring
* Yum repositoies mirroring
* DDns

Bootstrap
====================

Officially we rely on CI system to build our image.
If you'd like to build your own image, there's a very simple way to bootstrap without complicated setup.

Dependency
--------------------

All you need is a docker to run `docker build`, and a few basic Linux tools available everywhere.

* bash (>= 4.0)
* coreutils
* docker (>= 18.09)
* sudo
* which

We will handle `docker build` and `docker push` for you,
If you want to do it for a private docker registry, please `docker login` in advance.

Build
--------------------

```
docker login example.org -u your_user_name
dist=centos     # Support centos/ubuntu.
CI_REGISTRY_IMAGE=example.org/roaster CI_COMMIT_REF_NAME=build-init gitlab-ci/build_$dist.sh
```

`CI_REGISTRY_IMAGE` is mandatory and it should point to the base dir without `$dist`.
Make sure your registry supports hierarchical path.

`CI_COMMIT_REF_NAME` is optional.
You can use it to emulate a git tag `build-xxx` in our CI system, which allows you to start build from a certain stsage.
We also support `resume-xxx` it the previous build failed and a breakpoint image is created.

License
====================

We are using Apache License 2.0 for this entire repo.

Each component we build may has its own license, and does not need to be compatible with our license.
Users are responsible for maintaining proper licenses for all components used.
This requirement also applies when using our release packages (containers, tarball, deb, rpm, ...).

Contribution
====================

This project is hosted on private git and mirrored to GitHub.
Feel free to submit PR directly on Github and I will import it.

Where to Start
--------------------

To add a new library, you need to provide a build script, add it to entry script, and provide packaging spec if needed.

**Linux**

1. Add a new `pkgs/foo.sh` for build/test/packaging.
2. Add it to `setup.sh`.
3. Try with `./setup.sh foo`.
4. Add to proper build stage of dockerfile for all distros.
5. Send out a PR.

**Windows**

1. Add a new `win/pkgs/foo.ps1` for build/test/install.
2. Add it to `win/setup.ps1`.
3. Try with `win/setup.ps1 foo`.
4. Add nuget files (usually `.nuspec` and `.targets`) to new dirs in `win/nuget`.
5. You may need to divide large packages into `-dev` or `-debuginfo` to meet size limits of nuget feed.
6. Add them to win/pack.ps1`.
7. Have a try with `win/pack.ps1` if you can.
8. Send out a PR.

Guidelines
--------------------

**Overall Architecture**

![Architecture Diagram]/(doc/arch.pdf)

**Build Args:**
  * Build as shared lib when possible.
    CMake projects can usually handle this with either `-DBUILD_SHARED_LIBS=ON` or project-specific switches.
  * Keep debug symbols as long as it does not hurt performance.
    Usually this means `-O3 -g` on Linux.
  * Build and run unit test from libs.
    Most missing files or symbols issue can be revealed in this step.
  * Use ninja-build instead of makefile when possible.
    It is faster and most CMake projects support it implicitly.
  * Try if you can run unit tests in parallel using `CTEST_PARALLEL_LEVEL`.
    Some projects may have assumption on serial execution (e.g. I/O with shared files) so be careful.
  * Use latest compiler avaiable in distro, unless it does not work (mostly nvcc related).

**Library Selection**
  * Currently we only support popular libs with active development and maintenance.
    This ensures we can fix issues in upstream, without too many fancy tricks in our repo.
  * For library already available in distro we support, we only add them if:
      - Distro build is too old.
      - Distro build is not old currently but will be based on their track record.
      - Distro build has some issues, e.g. Ubuntu tends to have install path misaligned with upstream assumptions.
      - Distro build does not have certain build flags we need.
      - We are also the developer of lib and need to frequently rebuild non-released version.
