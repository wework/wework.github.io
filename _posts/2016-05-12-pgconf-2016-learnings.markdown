---
layout:       post
title:        The State of PostgreSQL 9.6: PGConf 2016 Takeaways
author:       gabby_losch
summary:      
image:        http://res.cloudinary.com/wework/image/upload/v1462568584/pgconf.jpg
categories:   databases
---

##All hail PostgreSQL!

Here at WeWork, we rely on PostgreSQL for our data needs. From our member-facing and public technologies to our internal tools, PostgreSQL has us covered. That's why a few of us on the engineering team jumped at the chance to nerd out for a few days at PGConf 2016. How better to spend the first nice days of spring than in a windowless hotel conference room in Downtown Brooklyn?

Over three days, we delved into lesser-known features, learned about additions coming to version 9.6, and soaked up the shared knowledge of the community.

###PostGIS

At the time of writing, WeWork has just shy of 100 locations in 9 countries, with more on the way. Given the huge footprint, having high-quality location and mapping data is a must. Also, we really love maps. Enter [PostGIS](http://postgis.net/).

Leo Hsu and Regina Obe, authors of PostGIS in Action, gave a great presentation. Here are some of the highlights. 

####Results Within a Specified Distance

Using [ST_Distance](http://postgis.net/docs/ST_Distance.html), we can return a list of locations based on distance from a fixed point. If that fixed point is your WeWork office, and the locations come from API calls to Yelp, then we've just found all possible lunch spots. Or ice cream places around the park. Or bakeries in your neighborhood. I think I might just be hungry.

~~~ sql
    SELECT name, other_tags­>'amenity' As type,
        ST_Distance(pois.geog,ref.geog) As dist_m
    FROM brooklyn_pois AS pois, (SELECT ST_Point(­73.988697, 40.69384)::geography) As ref(geog)
    WHERE other_tags @> 'cuisine=>indian'::hstore
    AND ST_DWithin(pois.geog, ref.geog, 1000)
    ORDER BY dist_m;
~~~

~~~ sql
    name | type       | dist_m
    ‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐

    Asya | restaurant | 704.31393886
    (1 row)
~~~

####Render 3D content

When paired with [X3DOM](http://www.x3dom.org), PostGIS can render 3D shapes directly into HTML. The results are a bit boxy, but if you don't need high levels of detail, then this is a great solution with little overhead.

####DateTime Ranges

PostGIS has a whole slew of built-in functions to handle datetime calculations and manipulations, including collapsing contiguous ranges into a single range, and consolidating discontinuous or overlapping ranges. This can be particularly useful in ensuring that we maintain clean, understandable usage data around our conference room bookings and tour schedules for buildings. 

~~~ sql
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
~~~

~~~ sql

    id | to_daterange

    ‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐‐

    1 | [1970‐11‐05,1975‐01‐01)
    1 | [1975‐11‐05,infinity)
    (2 rows)
~~~

This is obviously a very simplified example with minimal data. But imagine starting with thousands and thousands of rows -- from such simplified output, we can extrapolate meaningful data such as when our conference rooms are most heavily in use and which ones are most-often booked. This helps us determine how many conference rooms new buildings should have, and what sizes they should be. 

###Don't lock your tables

As your data grows and becomes more complex, your needs and the way you interact with it will likely also change. This is perfectly normal, but typically requires modifying your schema. Avoid locking your precious production tables by following some general rules (care of [Lukas Fittl](http://twitter.com/LukasFittl) of Product Hunt):

- Don't remove columns on large tables
- Don't rename columns*
- Always index concurrently
- Carefully change the column type
- Carefully add columns with a DEFAULT
- Carefully add NOT NULL columns
 (note the theme of using care)

*You may be thinking that this suggestion prevents you from making a necessary change to your tables. The key (inadvertent database pun, I swear) is to duplicate any data you'd like to change, make changes to the duplicate, then point your application to the new data. Once that's done, you can delete the old data. This process ensures that the production data isn't locked by the changes. 

###PostgreSQL Version 9.6

It's gonna be faster. Like, out of the box. You won't have to do anything. 

![Wooo!](http://res.cloudinary.com/wework/image/upload/v1462566101/engineering/colbert_celebration.gif){: style="margin: 0 auto; display: block"}

Thanks to the team behind PGConf for putting on a great event! 
