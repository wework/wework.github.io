---
layout:       post
title:        Caching External APIs in Rails for a Ginormous Speed Boost
author:       Matt Star
summary:      How to use Rails Fragment Caching to cache external APIs.
image:        http://res.cloudinary.com/wework/image/upload/s--unWFH26o--/c_fill,fl_progressive,g_north,h_1000,q_jpegmini,w_1600/v1430251626/engineering/caching-external-apis.jpg
categories:   engineering
---

The ability to book tours on wework.com is one of our most important sales funnels. We currently use Salesforce as our main manager of tour times and potential leads. Fetching the available tour times from the Salesforce api can take anywhere from 2 to 10 seconds, depending on how hard we’re hitting it. This is clearly not ideal!


### First Iteration: Let's use Rails to cache the response

Using basic Rails fragment caching we cached the response for 24 hours:

```ruby
  cache_key = ["tour_times", params[:tour_date], params[:building_uuid]]

  result = Rails.cache.fetch(cache_key, expires_in: 24.hours) do
    salesforce_connection.fetch_available_tour_times(params[:tour_date], params[:building_uuid])
  end
```

We then expired the cache whenever someone booked a tour for that building:

```ruby
  Rails.cache.delete(["tour_times", opts[:tour_date], opts[:building_uuid]])
```

This went exceptionally well...at first. Check out this gaudy web external response time graph for this tour times end point:

![New Relic Cache Graph](http://res.cloudinary.com/wework/image/upload/c_scale,fl_progressive,w_1000/v1430252408/engineering/caching-external-apis-graph.jpg)

#### Problems with First Iteration:

WeWork.com isn't the only place we can book a tour for potential members. Unfortunately, the cache was only being expired when a tour was created on wework.com. We can use Salesforce's UI among other custom services that we have in our systems to book tours. The cache was becoming stale without us knowing it. BOO!

We also noticed that even when expiring caches based on specific cache keys, there were still inconsistencies with our cache keys (deleting the wrong ones for example). It was a mess keeping track of the correct cache keys and only deleting the necessary ones.

### Second Iteration: Use an ActiveRecord object as the cache key

I read [this fantastic article](https://signalvnoise.com/posts/3113-how-key-based-cache-expiration-works) by DHH that I'd like to summarize here (although you should still totally read it).

 * Expiring cache values by deleting a cache associated with a static key and re-fetching new data = BAD
 * Using an Active Record object in your cache key, and UPDATING that record to create a brand new cache = GOOD

When you use the Active Record object it just creates a brand new fresher cache key-value pair. There are no consequences because Memcache knows to properly delete the older caches if you run out of memory.

Here's the new code following the above rules:

```ruby
  cache_key = [tour_object, params[:tour_date], params[:building_uuid]]

  result = Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      response = sf_connection.fetch_available_tour_times(params[:tour_date], params[:uuid])
  end
```

The cache_key now allows us to “touch” the most recent tour booked for any location to automatically refresh our cache of available tour times. Now, whenever we book a tour in Salesforce, we have the Salesforce API (through a [workflow rule](https://help.salesforce.com/HTViewHelpDoc?id=creating_workflow_rules.htm)) hit WeWork.com and update the most recent booked tour. It automatically flushes the tour from that building, and we have no more stale tour times.

Also, with the Second Iteration, this graph still looks pretty fantastic:

![New Relic Cache Graph 2](http://res.cloudinary.com/wework/image/upload/s--zhKANG-E--/c_scale,fl_progressive,q_jpegmini,w_1000/v1430253123/engineering/caching-external-apis-graph2.jpg)




