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
