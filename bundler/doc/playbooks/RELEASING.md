# Releasing

Bundler uses [Semantic Versioning](https://semver.org/).

_Note: In the documentation listed below, the *current* minor version number is
2.1 and the *next* minor version number is 2.2_

Regardless of the version, *all releases* must update the `CHANGELOG.md` and `lib/bundler/version.rb`
files. The changelog for the first stable minor release (`2.2.0`) is a sum of all
the preceding pre-release versions (`2.2.pre.1`, `2.2.pre.2`, etc) for that
minor version. The changelog for the first stable minor release is left blank
unless there are fixes included since the last pre/rc release.

## Workflow

In general, `master` will accept PRs for:

* feature merges for the next minor version (2.2)
* regression fix merges for a patch release on the current minor version (2.1)
* feature-flagged development for the next major version (2.0)

### Breaking releases

Bundler cares a lot about preserving compatibility. As a result, changes that
break backwards compatibility should (whenever this is possible) include a feature
release that is backwards compatible, and issue warnings for all options and
behaviors that will change.

We try very hard to only release breaking changes when incrementing the _major_
version of Bundler.

### Cherry picking

Patch releases are made by cherry-picking bug fixes from `master`.

When we cherry-pick, we cherry-pick the merge commits using the following command:

```bash
$ git cherry-pick -m 1 MERGE_COMMIT_SHAS
```

For example, for PR [#5029](https://github.com/rubygems/bundler/pull/5029), we
cherry picked commit [dd6aef9](https://github.com/rubygems/bundler/commit/dd6aef97a5f2e7173f406267256a8c319d6134ab),
not [4fe9291](https://github.com/rubygems/bundler/commit/4fe92919f51e3463f0aad6fa833ab68044311f03)
using:

```bash
$ git cherry-pick -m 1 dd6aef9
```

The `bin/rake release:prepare_patch` command will automatically handle
cherry-picking, and is further detailed below.

## Releases

### Minor releases

While pushing a gem version to RubyGems.org is as simple as `bin/rake release`,
releasing a new version of Bundler includes a lot of communication: team consensus,
git branching, documentation site updates, and a blog post.

Dizzy yet? Us too.

Here's the checklist for releasing new minor versions:

* [ ] Check with the core team to ensure that there is consensus around shipping a
  feature release. As a general rule, this should always be okay, since features
  should _never break backwards compatibility_
* [ ] Create a new stable branch from master (see **Branching** below)
* [ ] Create a PR to the stable branch that:
  * [ ] Updates `version.rb` to a prerelease number, e.g. `1.12.pre.1`
  * [ ] Updates `CHANGELOG.md` to include a release header for the new version, leaving the "(Unreleased)" section empty.
* [ ] Get the PR reviewed, make sure CI is green, and merge it.
* [ ] Pull the updated stable brnach, wait for CI to complete on it and get excited.
* [ ] Run `bin/rake release` from the updated stable branch, tweet, blog, let people know about the prerelease!
* [ ] Wait a **minimum of 7 days**
* [ ] If significant problems are found, increment the prerelease (i.e. 2.2.pre.2)
  and repeat, but treating `.pre.2` as a _patch release_. In general, once a stable
  branch has been cut from master, it should _not_ have master merged back into it.

Wait! You're not done yet! After your prelease looks good:

* [ ] Update `version.rb` to a final version (i.e. 2.2.0)
* [ ] In the [rubygems/bundler-site](https://github.com/rubygems/bundler-site) repo,
  copy the previous version's docs to create a new version (e.g. `cp -r v2.1 v2.2`)
* [ ] Update the new docs as needed, paying special attention to the "What's new"
  page for this version
* [ ] Write a blog post announcing the new version, highlighting new features and
  notable bugfixes
* [ ] Run `bin/rake release` in the bundler repo, tweet, link to the blog post, etc.

At this point, you're a release manager! Pour yourself several tasty drinks and
think about taking a vacation in the tropics.

Beware, the first couple of days after the first non-prerelease version in a minor version
series can often yield a lot of bug reports. This is normal, and doesn't mean you've done
_anything_ wrong as the release manager.

#### Branching

Bundler releases are syncronized with rubygems releases at the moment. That
means that releases for both share the same stable branch, and they should
generally happen together.

Minor releases of the next version start with a new release branch from the
current state of master: `3.2`, and are immediately followed by a prerelease
(might be a `.pre.1` version or a `.rc.1` version depending on the readiness of
the stable branch) or even directly by the final stable release.

The current conventional naming for stable branches is `x+1.y`, where `x.y` is
the version of `bundler` that will be released. This is because `rubygems-x+1.y`
will be released at the same time.

For example, `rubygems-3.2.0` and `bundler-2.2.0` will be both released from the
`3.2` stable branch.

Once a stable branch has been cut from `master`, changes for that minor release
series (bundler 2.2) will only be made _intentionally_, via patch releases.
That is to say, changes to `master` by default _won't_ make their way into any
`2.2` version, and development on `master` will be targeting the next minor
or major release.

### Patch releases (bug fixes!)

Releasing new bugfix versions is really straightforward. Increment the tiny version
number in `lib/bundler/version.rb`, and in `CHANGELOG.md` add one bullet point
per bug fixed. Then run `bin/rake release` from the appropriate stable branch,
and pour yourself a tasty drink!

PRs containing regression fixes for a patch release of the current minor version
are merged to master. These commits need to be cherry-picked from master onto
the minor branch (`3.2`).

There is a `bin/rake release:prepare_patch` rake task that helps with creating a patch
release. It takes a single argument, the _exact_ patch release being made (e.g.
`2.2.3`), but if not given it will bump the tiny version number by one. This
task checks out the appropriate stable branch (`3.2`), grabs the
`2.2.3` milestone from GitHub, ensures all PRs are closed, and then
cherry-picks those changes (and only those changes) to a new branch based off
the stable branch. Then bumps the version in the version file and commits that
change on top of the cherry-picks.

Now you have a release branch ready to be merged into the stable branch. You'll
want to open a PR from this branch into the stable branch and provided CI is
green, you can go ahead, merge the PR and run `bin/rake release` from the updated
stable branch.

## Beta testing

Early releases require heavy testing, especially across various system setups.
We :heart: testers, and are big fans of anyone who can run `gem install bundler --pre`
and try out upcoming releases in their development and staging environments.

There may not always be prereleases or beta versions of Bundler.
The Bundler team will tweet from the [@bundlerio account](https://twitter.com/bundlerio)
when a prerelease or beta version becomes available. You are also always welcome to try
checking out master and building a gem yourself if you want to try out the latest changes.
