Want to contribute? Great!
- First, read this page (including the small print at the end).
- Second, please make pull requests against develop, not master. If your patch
  needs to go into master immediately, include a note in your PR.

### Before you contribute
Before we can use your code, you must sign the
[Google Individual Contributor License Agreement](https://cla.developers.google.com/about/google-individual)
(CLA), which you can do online. The CLA is necessary mainly because you own the
copyright to your changes, even after your contribution becomes part of our
codebase, so we need your permission to use and distribute your code. We also
need to be sure of various other things—for instance that you'll tell us if you
know that your code infringes on other people's patents. You don't have to sign
the CLA until after you've submitted your code for review and a member has
approved it, but you must do it before we can put your code into our codebase.
Before you start working on a larger contribution, you should get in touch with
us first through the issue tracker with your idea so that we can help out and
possibly guide you. Coordinating up front makes it much easier to avoid
frustration later on.

### Code reviews
All submissions, including submissions by project members, require review. We
use Github pull requests for this purpose.

### The small print
Contributions made by corporations are covered by a different agreement than
the one above, the
[Software Grant and Corporate Contributor License Agreement](https://cla.developers.google.com/about/google-corporate).

### Updating dependency projects

For simplicity purposes, dependency projects for Blockly are maintained as copies inside the repo
and are managed using [Carthage](https://github.com/Carthage/Carthage).

Any pull requests looking to update these dependencies should follow this process:

1. Open a terminal window and navigate to Blockly's root directory.
2. Execute `carthage update`. This will create a root folder named `Carthage` with all dependency
projects.
3. Delete the folder `third_party/Carthage`.
4. Move the `Carthage` folder to `third_party/Carthage`.
