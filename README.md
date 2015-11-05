## TLDR;

- gem install jekyll
- gem install bundler
- bundle
- bundle exec jekyll serve --watch --drafts


## Getting Started

If you're completely new to Jekyll, I recommend checking out the documentation at <http://jekyllrb.com> or there's a tutorial by [Smashing Magazine](http://www.smashingmagazine.com/2014/08/01/build-blog-jekyll-github-pages/).

### Installing Jekyll

If you don't have Jekyll already installed, you will need to go ahead and do that.

```
$ gem install jekyll
```

#### Verify your Jekyll version

It's important to also check your version of Jekyll since this project uses Native Sass which
is [only supported by 2.0+](http://jekyllrb.com/news/2014/05/06/jekyll-turns-2-0-0/).

```
$ jekyll -v
# This should be jekyll 2.0.0 or later
```

### Jekyll Serve

Then, start the Jekyll Server. I always like to give the `--watch` option so it updates the generated HTML when I make changes.

```
$ gem install bundler
$ bundle
$ bundle exec jekyll serve --watch --drafts
```

Now you can navigate to `localhost:4000` in your browser to see the site.

NOTE: passing the --drafts flag will also load all posts inside of the _drafts folder. This is
useful when you are working on a post but are not ready to publish it yet.


### Need a Cool Photo?

To keep some visual consistency on our blog, it is recommended to use a photo by this illustrator.
[Olga Angelloz's Portfolio on Shutterstock](http://www.shutterstock.com/gallery-1451378p1.html)

The credentials are in Meldium.
