# Nuttall

## _This Is A Work In Progress_

- At this time, this project is __not__ complete.
- This file is a description of the _vision_ for this project.
- Some of the functionality is written and tested, but the large set of required features is not fully defined or tracked.

Eventually the `Issues` tab will be used to track upcoming features, but for now this is a simple labor of love and curiosity, something to keep me busy.

If there is any community interest in accelerating this project, then of course I will dedicate a much larger proportion of time and energy to it.

## Overview

Nuttall is a new way to deploy and manage centralized logging. Over my many years as a software product engineer and devops engineer, I have become more and more disappointed in the popular options for industrial-strength centralized logging. Hopefully Nuttall will address current issues with the existing choices.

Features:
- Open-source and free to use foundation.
- Automated configuration and deployment.
- Centralized management from anywhere on your network.
- Easy integration with Kibana.
- Use your own local storage, don't pay for remote storage.
- Fully encrypted log storage.
- Fully containerized.
- Configurable automatic storage growth and management.
- Support queries across a cluster of log services.

Sample Session:<br>
![Sample Session](README/screenshot-20250124.jpg?raw=true "Sample Session")

## Getting Started

Requirements:
1. Be on a Linux distro with a recent Kernel.<br>Dev and testing is done on a 6.12+ kernel.
1. Have a recent Ruby installed.<br>Dev and testing is done with Ruby 3.4+.
1. Have a recent Docker installed.<br>Dev and testing is done with Docker 27.3+.

To run:
1. _This is not ready for general use._
1. _[In the future...]_<br>Install the Rubygem:
    ```shell
    $ gem install nuttall
    ```
1. Or, run directly from the git source:
    ```shell
    $ git clone git@github.com:lilole/nuttall
    $ cd nuttall
    $ exe/nuttall
    ```

## Contributing

This project is only one dude slamming code, when I have time and a tiny bit of inspiration.

If you are interested in the progress of this project, just create an Issue with the tab above, and we can go from there.

## License

This codebase for these components of Nuttall is released under the [Apache 2.0 License](LICENSE).
