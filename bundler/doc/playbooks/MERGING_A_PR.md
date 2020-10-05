# Merging a PR

Bundler requires all CI status checks to pass before a PR can me merged. So make
sure that's the case before merging.

Also, bundler manages the changelog and github release drafts automatically
using information from merged PRs. So, if a PR has user visible changes that
should be included in a future release, make sure the following information is
accurate:

* The PR has a good descriptive title. That will be the wording for the
  corresponding changelog entry.

* The PR has an accurate label. If a PR is to be included in a release, the
  label must be one of the following:

  * "bundler: security fix"
  * "bundler: breaking change"
  * "bundler: major enhancement"
  * "bundler: deprecation"
  * "bundler: feature"
  * "bundler: performance"
  * "bundler: documentation"
  * "bundler: minor enhancement"
  * "bundler: bug fix"

  This label will indicate the section in the changelog that the PR will take,
  and will also define the target version for the next release. For example, if
  you merge a PR tagged as "type: breaking change", the next target version used
  for the github release draft will be a major version.

Finally, don't forget to review the changes in detail. Make sure you try them
locally if they are not trivial and make sure you request changes and ask as
many questions as needed until you are convinced that including the changes into
bundler is a strict improvement and will not make things regress in any way.
