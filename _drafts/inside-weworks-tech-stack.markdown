---
layout:       post
title:        Inside WeWork's Tech Stack
author:       Matt Star
summary:
image:        http://res.cloudinary.com/wework/image/upload/s--unWFH26o--/c_fill,fl_progressive,g_north,h_1000,q_jpegmini,w_1600/v1430251626/engineering/caching-external-apis.jpg
categories:   engineering
---

Last week, our friends at Underdog featured <a href="http://blog.underdog.io/post/121350812362/wework-tackles-hardware-software-challenges" target="_blank">a story about our Tech Stack</a> written by one of our longest tenured Lead Software Developer's, Ramin Bozorgzadeh.

Be sure to check out the last bit about how we focused on making the Rails based wework.com as performant as possible, through CDN caching, and a bit of nifty Javascript tinkering.

Some choice words:

> "There are a number of ways to do this but the approach that we took involved loading our static homepage html from the CDN and then making a request for a very small piece of JavaScript as one of the first things in our page’s head...It first sets up the user’s session so that we can identify the user when running experiments and whatnot. It also retrieves some other data that we were originally putting into our Rails application layout..."

There's a lot more to check out in the article <a href="http://blog.underdog.io/post/121350812362/wework-tackles-hardware-software-challenges" target="_blank">over on Underdog</a> where we talk about our custom systems built to manage our 25,000+ membership base.

Check back soon for a more detailed write up of our process.




