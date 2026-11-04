# Publishing the GitHub Wiki

The user documentation lives in `docs/wiki/`. The `Publish Wiki` workflow copies
these Markdown pages to the separate GitHub Wiki repository after changes reach
`develop`. It can also be run manually from Actions on `develop`.

## One-time setup

1. Enable **Settings → General → Features → Wikis**.
2. Open **Wiki**, create the first page and save it. Enabling Wikis alone does not
   initialize the Git repository. Its initial content can be replaced by our Home page.
3. Create a personal access token for an account that can edit this Wiki. A classic
   token with `public_repo` scope is sufficient for a public repository; private
   repositories require `repo`. Set an expiration date. Treat this token as a secret.
4. Open **Settings → Secrets and variables → Actions → New repository secret**.
   Name it `WIKI_TOKEN` and paste the token as the value. Do not put it in a file.
5. Merge the Wiki files and workflow into `develop`. Open **Actions → Publish Wiki**
   to inspect the result or select **Run workflow** on `develop`.

The built-in `GITHUB_TOKEN` is not used to write the separate Wiki repository.
If publishing fails, check that the first Wiki page exists, that the token has not
expired, and that its owner can edit the Wiki.

## Editing

Edit maintained pages in `docs/wiki/` and submit a normal pull request. The filenames
are stable page URLs. Use relative links such as `[Installation](Installation)`.
Add new pages to `_Sidebar.md` and `Home.md`.

Changes made to maintained pages directly through the Wiki UI will be overwritten
by the next publication. Other Wiki pages are preserved. Deleting or renaming a
source page does not delete its old Wiki page: remove obsolete pages manually after
updating incoming links. Publishing uses a normal push, so concurrent Wiki edits
cause a failure instead of being force-overwritten; rerun after reviewing the edit.

Existing screenshots are reused from `docs/assets/` through raw GitHub URLs on
`develop`. App UI strings remain in `lib/common/l10n/`; this workflow adds no app UI.

## Local publishing

With `GITHUB_REPOSITORY` and `WIKI_TOKEN` already exported in your environment, run
`bash tool/wiki/publish.sh`. Do not paste token values into committed scripts.

## References

- [Editing Wiki pages and cloning the Wiki](https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages)
- [GITHUB_TOKEN repository scope](https://docs.github.com/en/actions/concepts/security/github_token)
