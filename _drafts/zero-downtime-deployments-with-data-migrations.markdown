---
layout:       post
title:        Zero-Downtime Deployments with Data Migrations
author:       On Freund
summary:
image:        http://res.cloudinary.com/wework/image/upload/v1429582552/zero-downtime-deployment.jpg
categories:   data
---

A few months ago I talked about how to [deploy with zero-downtime](https://www.google.com/url?q=https%3A%2F%2Fhakkalabs.co%2Farticles%2Fdowntime-deployment-is-solved-data-migration-isnt&sa=D&sntz=1&usg=AFQjCNGXUDCdD8SD3Ykhg0Jx7MehYsVk0Q). I can wait while you read it, but TL;DR Blue-Green deployment is the prevalent pattern - you have two versions of the code running at the same time, and you let traffic to one version die out as new traffic is directed to the other version.

Blue-Green is all you need in case you don’t have data migrations, but what happens if you do? This post will mainly cover SQL databases, but don’t think that schemaless no-SQL DB has your back - we’ll cover those in a future post. What do we mean by data migration? Any change to the way the data is represented. Either schema (add/remove/change columns/tables), or semantic (e.g. changing the way those lat/long fields are represented).

Data migrations sound easy enough, right? Deploy the code, run your migrations and you’re good to go. Unfortunately, that leaves a gap between your new code getting to production, and the data migration. Unless your code is backwards compatible with the old representation, which can be extremely hard to achieve in non-trivial cases, that won’t work. Ok, scratch that - We run migrations, deploy the code, and then we’re good. That could be even trickier, as now you’re requiring your old code to be future proof. The truth is even more complicated - Blue-Green deployment means you’re going to have two (or more) versions of the code running at the same time, communicating with a shared database.

Like almost everything in computing, to resolve this we need to figure out how to break this into smaller problems. Let’s start with the simple case - migrations that are simply additive. Additive migrations are ones that do not modify or delete existing data - adding a column is a perfect example. Handling those is as easy as the “Migrate -> Deploy” sequence we covered earlier. Much success and joy.

The next migration type we’ll cover are ones that strictly delete - e.g. removing a column or a table. These are also relatively easy to handle, just deploy and then migrate after the Blue-Green transition is complete.

Now we’re left with migrations that modify data - these are your column changes for example. How do you deal with those? Surprisingly, that’s also easy - you just never use them. The key is understanding that each modification can be represented as a combination of adding and deletion. Getting the details right is a bit tricky though.

Let’s look at an example: WeWork members can publish posts on our member network. Each post has a `member_id` field pointing at the poster. We want to change that from being an integer id that represents the member’s auto-increment id, to a UUID field that uniquely identifies the member across systems.

Here’s a recipe for great success:

1. Run a migration to add a `member_uuid` field
1. Deploy of a version of the code that updates the `member_uuid` field whenever the `member_id` field is updated
1. Run a one-off task to populate the `member_uuid` field for all the existing records
1. Deploy a version of the code that solely relies on the `member_uuid` field
1. Run a migration to remove the `member_id` field

Let’s see why it works:
After step #1, all you did was add a column, and everything continues to function normally. You then go ahead with step #2, and since your code is still using `member_id` for everything, you’re safe. After step #3, (important: make sure the Blue-Green cycle for #2 is complete before running #3), you know that every record has its `member_uuid` populated correctly. You’re then ready for step #4, and once its cycle is complete, no code is using the `member_id` field in more, at which point it’s safe to remove it (#5). You’ve successfully averted dreaded downtime.

So now we know how to zero-downtime deploy for fun and profit. Next time we’ll cover no-SQL databases - why schemaless is not enough, and what’s there to do about it.
