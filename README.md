## TLDR;

- gem install jekyll
- gem install bundler
- bundle
- bundle exec jekyll serve --watch --drafts


## Getting Started

If you're completely new to Jekyll, I recommend checking out the documentation at <http://jekyllrb.com> or there's a tutorial by [Smashing Magazine](http://www.smashingmagazine.com/2014/08/01/build-blog-jekyll-github-pages/).

### Installing Jekyll

If you don't have Jekyll already installed, you will need to go ahead and do that. I've had issues with 2.5.6 and the major ^3.0.1 upgrades.

```
$ gem install jekyll -v 2.4.0
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
$ bundle exec jekyll serve --watch --drafts
```

Now you can navigate to `localhost:4000` in your browser to see the site.

NOTE: passing the --drafts flag will also load all posts inside of the _drafts folder. This is
useful when you are working on a post but are not ready to publish it yet.


## Writing a Post

Make sure to have all proper markup filled out at the top of your post to get that SEO boost.

Here's a good example:
```
---
layout:       post
title:        Rabbits, Bunnies and Threads
author:       Sai Wong
summary:      When writing Ruby, we sometimes take advantage of the single threaded nature of the environment and forget some of the pitfalls of being thread safe. When using servers such as Puma that allow us to take advantage of thread to maximize on performance, we found an issue with our Bunny implementation. The issue was identified as a documented inability for Bunny channels to be shared across threads and we developed a solution to address the issue.
image:        http://res.cloudinary.com/wework/image/upload/s--GnhXQxhq--/c_scale,q_jpegmini:1,w_1000/v1445269362/engineering/shutterstock_262325693.jpg
categories:   ruby rails bunny rabbitmq threads concurrency puma errors
---
```

### Need a Cool Photo?

To keep some visual consistency on our blog, it is recommended to use a photo by this illustrator.
[Olga Angelloz's Portfolio on Shutterstock](http://www.shutterstock.com/gallery-1451378p1.html)

The credentials are in Meldium.
