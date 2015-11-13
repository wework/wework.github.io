---
layout:       post
title:        Rabbits, Bunnies and Threads
author:       Sai Wong
summary:      When writing Ruby, we sometimes take advantage of the single threaded nature of the environment and forget some of the pitfalls of being thread safe. When using servers such as Puma that allow us to take advantage of thread to maximize on performance, we found an issue with our Bunny implementation. The issue was identified as a documented inability for Bunny channels to be shared across threads and we developed a solution to address the issue.
image:        http://res.cloudinary.com/wework/image/upload/s--GnhXQxhq--/c_scale,q_jpegmini:1,w_1000/v1445269362/engineering/shutterstock_262325693.jpg
categories:   ruby rails bunny rabbitmq threads concurrency puma errors
---

## Rabbits, Bunnies and Threads
We use [RabbitMQ](https://www.rabbitmq.com/) to publish many events on our platform. These events can come for a variety of sources including our web tier and or worker tier. For the most part, the system runs very well and the events are reliably published and the subscribers reliably receive the events. For simple event publishing and subscribing, RabbitMQ is a very robust solution that’s used by many platforms.

We do occasionally get the odd error message in our logs:

```
Bunny::ConnectionClosedError: Trying to send frame through a closed connection. Frame is #<AMQ::Protocol::MethodFrame:0x007f16a0c4d110 @channel=1>, method class is AMQ::Protocol::Exchange::Declare
```

For the most part, we just chalked it up to possible flakiness due to us constantly deploying and the workers disconnecting and reconnecting to RabbitMQ when they are restarted. When we started to get more of these and since they coincided with lost events on the platform, we decided to do a deeper investigation.

### Down the Bunny Hole
We use the [Bunny](http://rubybunny.info/) gem to handle the abstractions of our RabbitMQ connection. The gem is heavily supported and used by many projects so we know that it’s pretty battle tested. Digging a bit deeper, we noticed that we always receive this warning message in our logs as a precursor to the `ConnectionClosedError`.

```
Bunny::UnexpectedFrame: Connection-level error: UNEXPECTED_FRAME - expected content header for class 60, got non content header frame instead
```

We tried to reproduce this locally but running several web instances and worker instances all rapidly publishing events concurrently but was not able to see the same error. We even tried randomly restarting the workers to no avail. 

After some aggressive googling, the experts in the field seem to suggest that this was related to a shared channel between threads. Quickly looking at our setup, we realized that to save on connection cost when using the Bunny gem to publish, we cache the connection once and reuse it for subsequent calls.

```ruby
 def self.channel
  return $rabbitmq_channel if $rabbitmq_channel.present? && $rabbitmq_channel.open?

  Rails.logger.info "Initializing RabbitMQ"
  connection = Bunny.new
  connection.start
  Rails.logger.info "Connection established with rabbitmq on #{connection.host}#{connection.virtual_host}"
  $rabbitmq_channel = connection.create_channel
end
```

Reading the code, however, made us see that we were also caching the channel. Now caching the channel is probably good as well since there is a cost to opening and closing new channels. What we don’t know, though, is where we are sharing the connection/channel with other threads.

### Catching the Puma by the Tail
For many of our applications, we use Unicorn to raise up multiple workers to handle the influx of web requests. The way [Unicorn](http://unicorn.bogomips.org/) works is that it starts up a new instance of the Rails application as a new process for each worker and when the application is ready to take incoming requests, it redirects it to that worker. In that paradigm, there is no sharing of connection between threads since each process only operates on its own.

We did, however, recently switch to using [Puma](http://puma.io/) as our Rails server for some of our applications due to it’s memory and performance gains. Specifically, the application that was exhibiting the connection issues were switch as well. Puma is similar to Unicorn in that it starts up a new instance of the Rails application as a new process and directs requests to that worker when ready. However, Puma also allows you to increase your memory efficiency and better leverage concurrency by using threads instead. What that means is that instead of starting up a new Rails instance for each worker and allowing that worker to process one request at a time, Puma takes that same worker and binds several threads to it. Each thread can then each handle requests in parallel (or as parallel as your Ruby threading implementation allows).

Since the threads act on the same instance and memory space as the singular worker, they can be started up very quickly. The drawback, however is that you must ensure that your application is Thread Safe. There’s an excellent post called ["How Do I Know Whether My Rails App Is Thread-safe or Not?"](https://bearmetal.eu/theden/how-do-i-know-whether-my-rails-app-is-thread-safe-or-not/) on thread safety and Rails applications so I won’t go into the details of that here. Suffice to say, Rails has been considered thread safe since 2.2 so using threads in Puma is a great idea. However, by looking at our implementation we can see we have a gotcha.

### Sharing the Pool for Fun and Profit
With each thread using the same instance memory space of the same worker, that means that our caching of the Bunny connection and channel will not do. The documentation on Bunny provides more insight:

[http://rubybunny.info/articles/concurrency.html#sharing_channels_between_threads](http://rubybunny.info/articles/concurrency.html#sharing_channels_between_threads)

So the docs say that we can share the connection but channels are a definite no-go. Since our event publishing code was wrapped in a utility gem used by many different applications, we wanted to devise a solution that was backwards compatible. Since the channel requested can be used by both publishing and subscribing, it was not feasible for us to use an ephemeral channel implementation since we don’t want to accidentally close a channel used for subscribing. The solution we came up with was to simply pool our opened channels. Luckily there’s a great `connection_pool` gem that does exactly that and allows us to abstract that out cleanly:

```ruby
require 'connection_pool'

def channel
  @channel_pool ||= ConnectionPool.new do
    connection.create_channel
  end
end
```

The result of deploying that change? All `ConnectionClosedError` and `UnexpectedFrame` errors has gone away and we haven’t experienced a missed event since! 

### Conclusion
When writing Ruby, we sometimes take advantage of the single threaded nature of the environment and forget some of the pitfalls of being thread safe. When using servers such as Puma that allow us to take advantage of thread to maximize on performance, we found an issue with our Bunny implementation. The issue was identified as a documented inability for Bunny channels to be shared across threads and we developed a solution to address the issue. The main take away here, read the documentation regardless of how dry it is!

### Related Links
1. [https://www.rabbitmq.com/](https://www.rabbitmq.com/)
2. [http://unicorn.bogomips.org/](http://unicorn.bogomips.org/)
3. [https://bearmetal.eu/theden/how-do-i-know-whether-my-rails-app-is-thread-safe-or-not/](https://bearmetal.eu/theden/how-do-i-know-whether-my-rails-app-is-thread-safe-or-not/)
4. [http://puma.io/](http://puma.io/)
5. [http://rubybunny.info/](http://rubybunny.info/)
6. [http://rubybunny.info/articles/concurrency.html#sharing_channels_between_threads](http://rubybunny.info/articles/concurrency.html#sharing_channels_between_threads)
7. [http://reference.rubybunny.info/Bunny/Channel.html](http://reference.rubybunny.info/Bunny/Channel.html)
8. [https://github.com/mperham/connection_pool](https://github.com/mperham/connection_pool)
