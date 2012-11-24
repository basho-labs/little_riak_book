# Introduction

## What is Riak

Riak is an open-source, distributed key/value database for high availability, fault-tolerance, and near-linear scalability. It's a mouthful, that basically means Riak has high uptime, and grows with you.

In an increasingly interconnected world, major shifts have occurred in data management. The web and connected devices have spurred an explosion of both data collection and access unseen in the history of the world. The amount of data being stored and managed has grown at a staggering rate, and in parallel, more people than ever require fast and reliable access to this data. This is generally called *Big Data*.

<aside id="big-data" class="sidebar"><h3>So What is Big Data?</h3>

There's a lot of discussion around what constitutes <em>Big Data</em>.

I have a 6 Terabyte RAID in my house to store videos and other backups. Does that count? On the other hand, CERN grabbed about [200 Petabytes](http://www.itbusinessedge.com/cm/blogs/lawson/the-big-data-software-problem-behind-cerns-higgs-boson-hunt/?cs=50736) looking for the Higgs boson.

It's a hard number to pin down, because Big Data is a personal figure. What's big to one might be small to another. This is why many definitions don't refer to byte count at all, but instead about relative potentials. A reasonable, albeit wordy, [definition of Big Data](http://www.gartner.com/DisplayDocument?ref=clientFriendlyUrl&id=2057415) is given by Gartner.

<blockquote>Big Data are high-volume, high-velocity, and/or high-variety information assets that require new forms of processing to enable enhanced decision making, insight discovery and process optimization.</blockquote></aside>

The sweet spot of Riak is high-volume (data that's available to read and write when you need it), high-velocity (easily responds to growth), and high-variety information assets (you can store any type of data as a value).

Riak was built as a solution to real Big Data problems, based on the *Amazon Dynamo* design. Dynamo is a highly available design---meaning that it responds to requests quickly at very large scales, even if your application is storing and serving terabytes of data a day. Riak had been used in production prior to being open-sourced in 2009. It's currently used by Github, Comcast, Voxer, Disqus and others, with the larger systems storing hundreds of TBs of data, and handling several GBs per node daily.

Riak was written on the Erlang programming language. Erlang was chosen due to its strong support for concurrency, solid distributed communication, hot code loading, and fault-tolerance. It runs on a virtual machine, so running Riak requires you also have Erlang installed.

So should you use Riak? A good rule of thumb for potential users is to ask yourself if every moment of downtime will cost you in some way (money, users, etc). Not all systems require such extreme amounts of uptime, and if you don't, Riak may not be for you.

## About This Book

This is not an "install and follow along" guide. This is a "read and comprehend" guide. Don't feel compelled to have Riak, or even have a computer handy, when starting this book. You may feel like installing along at some point, and if so, instructions can be found on the [Riak docs](http://docs.basho.com).

In my opinion, the most important section of this book is the [concepts chapter](#concepts). If you already have a little knowledge it may start slow, but it picks up in a hurry. After laying the theoretical groundwork, we'll move onto helping [developers](#developers) use Riak, by learning how to query it and tinker with some settings. Finally, we'll go over the basic details that [operators](#operators) should know, such as how to set up a Riak cluster, configure some values, reading logs, and more.
