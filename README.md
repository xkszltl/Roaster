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
