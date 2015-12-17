---
layout:       post
title:        Additional tips on improving scrolling performance of a UICollectionView
author:       amit_rao
summary:      Recently we improved the scrolling performance of the WeWork iOS app with the goal of getting as close to 60 fps consistently as possible. The blog post describes my experience solving the issue and adding to some of the existing online resources related to the issue.
image:		  http://res.cloudinary.com/wework/image/upload/v1430060208/engineering/recruiting-through-gamification.jpg      
categories:   engineering
---

#### What does optimizing scrolling performance mean and why is it important? 

In order to provide users with a UI experience that is fast and responsive it is important to gain knowledge into the finer details of graphics optimization, efficient layout and rendering. 


#### Problem and Learnings

Recently I spent some time optimizing the scrolling performance of a `UICollectionView` so that the scrolling is now 60 fps (frames per sec) and buttery smooth (iPhone 5/6/6s)  I followed some hints on a [Ray Wenderlich tutorial](http://www.raywenderlich.com/86365/asyncdisplaykit-tutorial-achieving-60-fps-scrolling) which links to a very good [WWDC 2012 video](https://developer.apple.com/videos/play/wwdc2012-238/) on iOS app performance: graphics & animations. If you happen to run into these issues you will find these videos/articles quite useful. We were observing janky behavior on the main landing view of the [WeWork iOS app](https://itunes.apple.com/us/app/wework-community-creators/id776177942?mt=8) that is a `UICollectionView`. The jankiness during scrolling was clearly visible and here are the frame rates that we were observing before any optimizations. 

![FPS before][1]
[1]: http://res.cloudinary.com/wework/image/upload/v1450306055/engineering/Screen_Shot_2015-12-04_at_9.52.09_AM.png


In our case after running the Core Animation intrument and baselining performance it turned out the issue was GPU bound and the renderer was doing a lot of work. The scrolling was visibly jittery and the Core Animation instrument showed 45 - 55 fps while scrolling on the collection view. After using the simulator and Core Animation instrument to enable **color blended layers** it was clear that there were a number of CA layers being rendered.  Often in such cases UIImages can be the bottleneck. Either the images are being loaded  without using `imageNamed` or the resolution of the image is too high e.g. a large image being loaded into a thumbnail view.  What is interesting in the video is that the Apple engineer recommends using the platform's built in caching support, async drawing support & flattening support before pulling out the heavy tools. It is also important to make sure one is reusing cells etc. In this case eliminating blending of the layers in the various subviews of the `UICollectionViewCell` gave the most bang for the buck and was a solution we could live with. The general methodology is to determine if it a CPU or GPU bound issue using the CA Instrument. Come up with a theory and baseline, then make code changes and measure again. See if there is improvement and record all measurements. The WWDC video recommends some other tips worth checking out and  speculative caching is another powerful technique. You might want to check out `NSCache/NSPurgeable` especially for images. Facebook’s *AsyncDisplayKit* might be worth checking out especially if one is developing an app from scratch (We did not use it). Here are the frame rates after blending all the CA layers in the collection view cells. 

![FPS after][2]
[2]: http://res.cloudinary.com/wework/image/upload/v1450306072/engineering/Screen_Shot_2015-12-07_at_3.51.58_PM.png

#### Additional Tips

To add Re: image rendering, in addition to *Debug > Color Blended Layers*, you can use  *Debug > Color Misaligned Images* to show scaled images in yellow and misaligned images in magenta. The best bet for fast scrolling is no blending, no scaled images, no misaligned images, no shadows modulo what you can live with with respect to design. 

To improve the thumbnail insertion if you have significant number of thumbnail images, consider using `NSCache/NSPurgeable` for the thumbnail images. In other words, create the thumbnail image on the fly and store the result in a cache (speculative caching) based on a key using the cell or record ID. Then the next time the image is needed, rather than recalculating/resizing you re-use the cached image. If it has been purged, you recalculate.  This is pretty straightforward and can be used for all scrolling which has a number of images which are expensive to either generate or retrieve. It is also what the Apple home screen uses for all the App Icons.

There is a WWDC talk Re: [how Apple implemented the home screen scrolling](https://developer.apple.com/videos/play/wwdc2015-212/) and all of the parameters they had to consider such as cache size, memory usage vs cache usage. It is an excellent talk for understanding `NSCache/NSPurgeable`.

Hope this helps.





