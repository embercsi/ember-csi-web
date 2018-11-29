# Website for ember-csi.io

The website is generated using [Hugo](https://gohugo.io/) to generate static web pages.

To install hugo on a Fedora system we can do:

```
$ sudo dnf install hugo
```

The source for the website is kept in the `master` branch, and the current published website goes into the `gh-pages`.  This way se can make incremental changes to the web without publishing it.

To facilitate the publication process we use git's worktree functionality, so the first time we clone the project we need to run:

To test how our web would look like we can just execute the `hugo` command from the project's root directory.

If we try to see the `public/index.html` page we'll notice that it doesn't look good due to the absolute paths used in the static pages.  To properly see the pages we need to serve the pages, which can easily be done using `hugo`:

```
$ hugo server
                   | EN
+------------------+----+
  Pages            | 10
  Paginator pages  |  0
  Non-page files   |  0
  Static files     | 37
  Processed images |  0
  Aliases          |  4
  Sitemaps         |  1
  Cleaned          |  0

Total in 49 ms
Watching for changes in /home/username/ember-csi-web/{content,data,static,themes}
Watching for config changes in /home/username/ember-csi-web/config.toml
Serving pages from memory
Running in Fast Render Mode. For full rebuilds on change: hugo server --disableFastRender
Web Server is available at //localhost:1313/ (bind address 127.0.0.1)
Press Ctrl+C to stop
```

Now the pages will be served on `localhost:1313` and any changes we do to the source files will be rendered automatically.


```
$ make init
```

When we are ready to generate the website and publish it we have to do:

```
$ MSG='Add my cool new post' make generate
$ make publish
```
