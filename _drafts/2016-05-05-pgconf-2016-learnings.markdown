---
layout:       post
title:        PGConf 2016 Takeaways
author:       gabby_losch
summary:      
image:        http://res.cloudinary.com/wework/image/upload/v1462568584/pgconf.jpg
categories:   conferences, industry, databases
---

##All hail PostgreSQL!

Here at WeWork, we rely heavily on PostgreSQL for our data needs. From our member-facing and public technologies to our internal tools, PostgreSQL has us covered. That's why a few of us on the engineering team jumped at the chance to nerd out for a few days at PGConf 2016. How better to spend the first nice days of spring than in a windowless hotel conference room in Downtown Brooklyn?!?!

Over three days, we delved into some lesser-known features, learned about the latest additions coming to version 9.6 and 9.5 patches, and generally soaked up the shared knowledge of the PG community.

###PostGIS

Here at WeWork, we love maps. At the time of this writing, WeWork has just shy of 100 locations in 9 countries, with more popping up seemingly every day. With such a huge footprint, having high-quality location and mapping data is a must. PostGIS provides some massively powerful features for our uses. Here are some highlights that were covered in a great demonstration by Leo Hsu and Regina Obe:

####Results Within a Specified Distance

Using [ST_Distance](http://postgis.net/docs/ST_Distance.html) and some basic API calls to Seamless, Yelp, or any other local aggregator/search engine, we can return a list of locations based on distance from a fixed point. If that fixed point is your WeWork office, this query could do everything from finding your next lunch spot, to the nearest ice cream place, to a great neighborhood bakery....I think I might just be hungry.

```
    SELECT name, other_tags­>'amenity' As type,
    ST_Distance(pois.geog,ref.geog) As dist_m
    FROM brooklyn_pois AS pois,
    (SELECT ST_Point(­73.988697, 40.69384)::geography) As ref(geog)
    WHERE other_tags @> 'cuisine=>indian'::hstore
    AND ST_DWithin(pois.geog, ref.geog, 1000)
    ORDER BY dist_m;
```

name | type | dist_m

‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐+‐‐‐‐‐

Asya | restaurant | 704.31393886
(1 row)

####Render 3D content

When paired with [X3DOM](http://www.x3dom.org), PostGIS can render 3D shapes directly into HTML. Imagine 3D renderings of our buildings on the [Locations Page](http://wework.com/locations) that you can move around. 

####DateTime Ranges

PostGIS has a whole set of built-in functions to handle datetime calculations and manipulations, including collapsing contiguous ranges into a single range, and consolidating discontinuous or overlapping ranges. This can be particularly useful in ensuring that we maintain clean, understandable usage data around our conference room bookings and building tour schedules. 

```
    SELECT id,
    to_daterange(
    (ST_Dump(
    ST_Simplify(ST_LineMerge(ST_Union(to_linestring(period))),0))
    ).geom)
    FROM (
    VALUES
    (1,daterange('1970­11­5'::date,'1975­1­1','[)')),
    (1,daterange('1980­1­5'::date,'infinity','[)')),
    (1,daterange('1975­11­5'::date,'1995­1­1','[)'))
    ) x (id, period)
    GROUP BY id;
```

id | to_daterange

‐‐‐‐+‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐

1 | [1970‐11‐05,1975‐01‐01)
1 | [1975‐11‐05,infinity)
(2 rows)

This is obviously a very simplified example with minimal data. But imagine starting with thousands and thousands of rows -- from such simplified output, we can extrapolate meaningful data such as when our conference rooms are most heavily in use and which ones are most-often booked. This helps us determine how many conference rooms new buildings should have, and what sizes they should be. 

###Don't lock your tables

As your data grows and becomes more complex, your needs and the way you interact with it will likely also change. Avoid locking your precious production tables by following some general rules (care of [Lukas Fittl](http://twitter.com/LukasFittl) of Product Hunt):

- Don't remove columns on large tables
- Don't rename columns
- Always index concurrently
- Carefully change the column type
- Carefully add columns with a DEFAULT
- Carefully add NOT NULL columns
 (note the theme of using care)

###PostgreSQL Version 9.6

It's gonna be faster. Like, out of the box. You won't have to do anything. ![Wooo!](http://res.cloudinary.com/wework/image/upload/v1462566101/engineering/colbert_celebration.gif)

Thanks to the team behind PGConf for putting on a great event! 
