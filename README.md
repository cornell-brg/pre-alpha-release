# Getting started
[Getting Started](GETTING_STARTED.md)

# Project Status
The next release of Black Parrot, v1.0, is coming in September 2019, and will contain support for an (up to) 16 core, cache-coherent, Linux-capable, RV64IA multicore.

# BlackParrot software developer guide
Coming soon!

# BlackParrot interface specification
Coming soon!

# BlackParrot microarchitectural specification
Coming soon!

# BlackParrot Manifesto
Always remember:
- Be TINY
    - When deliberating between two options, consider the one with least hardware cost/complexity.
- Be Modular
    - Prevent tight coupling between modules by designing latency insenstive interfaces.
- Be Friendly
    - Combat NIH, welcome external contributions and strive for infrastructure agnosticism.

# How to contribute
[Contribution Guide](CONTRIBUTING.md)

# BlackParrot style guide
[BlackParrot Style Guide](STYLE_GUIDE.md)

# CI
Below is the current status of BlackParrot CI builds. Upon commit to the listed branch, a Verilator-based regression consisting of full-system riscv-tests and module level tests is run and checked for correctness.

NOTE: Work is in progress to continuously verify synthesizability and PPA.

master: [![Gitlab
CI](https://gitlab.com/black-parrot/pre-alpha-release/badges/master/build.svg)](https://gitlab.com/black-parrot/pre-alpha-release/pipelines) 

dev: [![Gitlab CI](https://gitlab.com/black-parrot/pre-alpha-release/badges/dev/build.svg)](https://gitlab.com/black-parrot/pre-alpha-release/pipelines) 

fe_dev: [![Gitlab CI](https://gitlab.com/black-parrot/pre-alpha-release/badges/fe_dev/build.svg)](https://gitlab.com/black-parrot/pre-alpha-release/pipelines) be_dev: [![Gitlab CI](https://gitlab.com/black-parrot/pre-alpha-release/badges/be_dev/build.svg)](https://gitlab.com/black-parrot/pre-alpha-release/pipelines) me_dev: [![Gitlab CI](https://gitlab.com/black-parrot/pre-alpha-release/badges/me_dev/build.svg)](https://gitlab.com/black-parrot/pre-alpha-release/pipelines) sw_dev: [![Gitlab CI](https://gitlab.com/black-parrot/pre-alpha-release/badges/sw_dev/build.svg)](https://gitlab.com/black-parrot/pre-alpha-release/pipelines)
