# Testing Release Automation

When testing the release process, you'll create a release branch and a release draft, but you won't merge them. You will publish gems to RubyGems, but they will be marked pre-release.

- Do not merge the automatically-generated release bracnh. Instead, specify umerged branches explicitly on the command line. (See below.)
- Use a release version like `1.6.1.test.only.rc3` -- these will be automatically marked as pre-release on RubyGems, and users will not get them without explicitly asking for them.
- Each test run should use a different version string; RubyGems won't let you reuse one.
- After testing, yank the test gems from RubyGems.

## Prearing The Release

Specify your branch explicitly:

```
ruby release/scripts/prepare_release.rb 1.6.1.test.only.rc3 --base-ref origin/gmt/my-release-process-changes
```

Note that this test release branch will include your changes to the release code; this is fine, since you won't merge it.

## Publishing The Release

Specify the generated release branch explicitly:

```
gh workflow run release-publish.yml \
  --repo temporalio/sdk-ruby \
  --ref chore/release-1.6.1.test.only.rc3
```

## Yanking Test Gems

Yank the source gem and every platform gem.

```
gem yank temporalio -v 1.6.1.test.only.rc3
gem yank temporalio -v 1.6.1.test.only.rc3 --platform aarch64-linux
gem yank temporalio -v 1.6.1.test.only.rc3 --platform aarch64-linux-musl
gem yank temporalio -v 1.6.1.test.only.rc3 --platform x86_64-linux
gem yank temporalio -v 1.6.1.test.only.rc3 --platform x86_64-linux-musl
gem yank temporalio -v 1.6.1.test.only.rc3 --platform arm64-darwin
gem yank temporalio -v 1.6.1.test.only.rc3 --platform x86_64-darwin
```