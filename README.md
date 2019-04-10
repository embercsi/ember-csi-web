# Website for ember-csi.io

The website is generated using [Hugo](https://gohugo.io/) to generate static web pages.

To install hugo on a Fedora system we can do:

```
$ sudo dnf install hugo
```

The source for the website is kept in the `master` branch, and the current published website goes into the `gh-pages`.  This way se can make incremental changes to the web without publishing it.

To facilitate the publication process we use git's worktree functionality, so the first time we clone the project we need to run:

```
$ make init
```

To test how our web would look like we can just execute the `hugo` command from the project's root directory.

If we try to see the `public/index.html` page we'll notice that it doesn't look good due to the absolute paths used in the static pages.  To properly see the pages we need to serve the pages, which can easily be done using `hugo`:

```
$ make serve
hugo server --config config-serve.toml

                   | EN
+------------------+----+
  Pages            | 10
  Paginator pages  |  0
  Non-page files   |  0
  Static files     | 36
  Processed images |  0
  Aliases          |  4
  Sitemaps         |  1
  Cleaned          |  0

Total in 77 ms
Watching for changes in /home/geguileo/code/reuse-cinder-drivers/ember-csi-web/{content,data,static,themes}
Watching for config changes in config-serve.toml
Serving pages from memory
Running in Fast Render Mode. For full rebuilds on change: hugo server --disableFastRender
Web Server is available at http://localhost:1313/ (bind address 127.0.0.1)
Press Ctrl+C to stop
```

Now the pages will be served on `localhost:1313` and any changes we do to the source files will be rendered automatically.

Before we can generate the new website we have to sync our `gh-pages` branch with upstream.  Assuming we have called the `git@github.com:embercsi/ember-csi-web.git` repository `upstream` we would do:

```
$ cd public
$ git reset --hard upstream/gh-pages
```

Now that our `gh-pages` branch is in sync with upstream, we are ready to generate a commit with the new website and publish it:

```
$ make generate MSG='Add my cool new post'
$ make publish
```

And then generate a new PR from our fork's branch to the `embercsi/ember-csi-web` repository.

Reviewers should check locally the resulting website from the `gh-pages` PR before merging the patch and therefore publishing the changes.

This can be done by checking out the PR branch locally, for example like this:

```
$ cd public
$ git checkout -b pr-gh-pages
$ git pull https://github.com/Akrog/ember-csi-web.git gh-pages
```

And then serving the site using Python:

```
$ python -m SimpleHTTPServer 12345
```

Finally we just need to go with our browser to http://127.0.0.1:12345 and check the contents.
