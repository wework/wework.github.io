---
layout:       post
title:        Why WeWork.com uses a static generator and why you should too
author:       ramin_bozorgzadeh
summary:      Back when the web first started, things were a lot simpler. Most websites were made up of static html pages and there weren't a lot of moving parts. This is the story of how wework.com went from a monolithic "web app" to a statically generated site, and why ...
image:        //res.cloudinary.com/wework/image/upload/c_fill,f_auto,g_faces,h_800,w_1000/v1448734984/engineering/wework-com-is-going-static.jpg
categories:   engineering
---

### What is this "static" business all about?

Over the past few years, static site generators have become a hot topic, so much so that [entire sites](https://www.staticgen.com/) have emerged dedicated to tracking and rating them. Don't take my word
for it, check out this graph from [Google Trends for "static site generator"][2]:

[![Google Trends - Static Site Generator][1]][2]
[1]: http://res.cloudinary.com/wework/image/upload/f_auto/v1448735896/engineering/static-site-generator.png
[2]: https://www.google.com/trends/explore#q=static%20site%20generator

The idea is actually quite simple. On a traditional *dynamic* site, each page is processed and generated on the server per request (let's ignore caching strategies for the sake of argument.) If you consider the amount of information that changes on a daily, or even weekly basis on a site like [wework.com](https://www.wework.com), it is actually quite wasteful to have a server process each and every request that comes through. A static site, on the other hand, is processed and generated just **once** on each deploy and all the server has to do is serve up the resulting generated HTML. Of course, this is an overly simplified explanation of how it all works, and this process doesn't work as well on all sites, but it does work really well for marketing and informational sites like [wework.com](https://www.wework.com).


### Roots: The static / dynamic hybrid approach

One key requirement for us when evaluating different static site generators was the ability to hit an API endpoint and dynamically generate static pages based on the data returned. A real-world example of this is when we add new locations and markets. With a traditional web-app setup (like a Ruby on Rails project), as soon as you add a new location or update one, the new content is up and live on your website. With a statically generated site, this is not the case. You will need to rebuild the entire site and generate new HTML. The good news is, for a site that doesn't have a ton of content, this static site generation is actually really fast. Like in the tens of seconds fast. A couple of minutes if you consider the entire proecss of minifying assets, building and deploying your site.

We played with and evaluated quite a few options, like pure Jekyll, Yeoman, Middleman, etc. The one we decided to go with is a very well thought out static site generator called [**Roots**](http://roots.cx/), developed by the fine folks at the Brooklyn based agency, [Carrot Creative](https://carrot.is/). Besides the many nice features that Roots gives you right out of the box (folder structure, asset management and minifcation, great extension and plugin system, etc), they also have a really nifty extension called [**roots-records**](https://github.com/carrot/roots-records). Like most well built things, roots-records serves one purpose and does an amazing job at it. It allows you to hit ANY endpoint that returns a JSON collection and use that collection in your templates to iterate over or if you pass in a template, it will also generate individual static HTML pages for each item in the collection. For example, here is all we had to define in our `app.coffee` file to hit our API endpoint for our market/location:

```coffeescript
extensions: [
  records(
    marketsByCountry: {
      url:
        path: "#{process.env.API_ENDPOINT}/api/to/locations/data"
    }
  )
]
```

And here is how this data is referenced inside of our `jade` templates:

```jade
each countries, index in records.marketsByCountry
  .row
    .col-12.col
      h4
        != countries[0]
```

Once we are ready to move our individual location pages over to *static*, all we need to do is pass a `template` option to the `records` block in our app.coffee config, and Roots will generate the individual location pages when it builds the site. This would look something like this:

```coffeescript
extensions: [
  records(
    marketsByCountry: {
      url:
        path: "#{process.env.API_ENDPOINT}/api/to/locations/data"
      template: "views/_location.jade"
      out: (location) -> "/locations/#{location.market.slug}/#{location.slug}"
    }
  )
]
```


### Netlify: The static host with the most

One of the biggest challenges of this whole process has been to figure out a way to slowly migrate our site over from a dynamic app, over to a static one. One way to do this would be to stop all development for a few months and rebuild the entire site using this new infrastructure. But as the saying goes, "ain't nobody got time for that."

We needed a way to move things over piecemeal. One page at a time. This meant that we couldn't move wework.com to a new static host all at once, but at the same time, we needed some URLs to serve up the old content, and some URLs to serve up the new static pages. One way to do this is via a [reverse proxy](https://en.wikipedia.org/wiki/Reverse_proxy).

There are many different ways to skin this cat, ranging from Apache or Nginx configuration, using something like rack-reverse-proxy to a slew of other similar solutions, each with their own pros and cons. For us, being a team of web developers, we wanted to spend our time focusing on our KPI's and optimizing our pages for performance, and not on setting up and managing servers. We had a few requirements. Specifically, we were looking for a host that could:

- House our new static site and scale with us
- Have an API and webhooks so we can trigger builds when content changes
- Ability to proxy requests to other URLs (internal and external)
- Global CDN to improve performance and SEO for our international traffic
- Easy to use and configure
- Great and responsive customer support

We found one host that met all of those requirements and more, and they are called [Netlify](https://www.netlify.com/). Never heard of them? Neither had we, but as a colleague of mine recently put it, "Netlify is like the developer whisperer". This team has put together an amazing service that handles SO much for you from a dev-ops persective of hosting static sites. And if there is a feature that is missing, they will bend over backwards to either implement it for you, or help you figure out a solution. I can sit here and sing their praises all day long, but its probably best if I explained a bit about how they were able to help us with our migration to a static site and make the static verions of our site *2-3x faster*.

To get started, one of the first pages we decided to migrate over to static was our [`/locations`](https://www.wework.com/locations/) page. This page has dynamic content coming from our backend, so it seemed like a good place to start. Looking at the graph below you can see the downward trend (in the world of performance, downward trending graphs are usually a good thing) from the day we rolled it out, and also the steady performance since we launched it.

![Performance graph of locations page](http://res.cloudinary.com/wework/image/upload/c_scale,f_auto,w_1000/v1448740493/engineering/locations-graph.png)
<small>*Via [calibreapp.com](https://calibreapp.com/)*</small>

One can argue that the same level of performance can be achieved using CDN or Edge Caching, and this is definitely true. And in fact, edge caching is one of the many features that Netlify offers. But properly setting up your application to take advantage of edge caching, and then knowing when to invalidate that cache deserves a blog article on its own. As the saying goes, *"There are only two hard things in Computer Science: cache invalidation and naming things."* We've decided to spend more of our time on naming things :-)

So how are we serving up traffic to `wework.com/locations/` from the static host and other pages from our current non-static host? It was as simple has modiftying some DNS settings to route all traffic through Netlify, [creating a `_redirects` file](https://www.netlify.com/docs/redirects) at the root of our very basic static site, with some rules about which URLs to pass through and which ones to handle. Netlify's proxy and rewrite is actually very intelligent in how it handles requests. If it finds the file, folder or resource locally in your folder structure, it will serve that up before it tries to proxy it. On our site, we have a catch-all rule that looks like this:

```coffeescript
extensions: [
  netlify
    rewrites:
      '/':  process.env.ORIGIN_URL
      '/*':  process.env.ORIGIN_URL + '/:splat'
```

Which basically says, route all traffic through to `ORIGIN_URL`. We never have to touch this rule, and as soon as we added the `/locations/index.html` resource to our static site, Netlify was smart enough to serve that page vs proxying it through.


The reality is that we are currently maintaining two versions of our site as we move things over, but this allows us to continue doing business as usual, make updates to existing pages and not have to stop our normal workflow as we migrate things over little by little. What's great about all of this is that we are sharing the same data across both sites.

By doing this, we hope to see an improvement in SEO traffic and hopefully a small uptick in our KPI numbers, as it has been proven that conversion numbers generally improve when your pages load faster. This also allows us to expand globally without having to worry as much about traffic load and performance. One thing to keep in mind with all of this is that it is not necessarily *easier*, but it is a lot *simpler*. There is a [great article on Smashing Magazine](http://www.smashingmagazine.com/2015/11/modern-static-website-generators-next-big-thing/) written by the co-founder of Netlify (Mathias Biilmann Christensen) about why static site generators are the next big thing. I highly recommend checking it out.

Stay tuned for **part 2**, where we will discuss our journey into **Isomorphic / Universal Javascript** with React, and Webpack and generating our React components during our static site generation process for fun and for profit.






