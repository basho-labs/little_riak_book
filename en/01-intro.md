# Introduction

## Downtime Roulette

![Gambling With Uptime](../assets/decor/roulette.png)

Picture a roulette wheel in a casino, where any particular number has a 1 in 37 chance of being hit. Imagine you could place a single bet that a given number will *not* hit (about 97.3% in your favor), and winning would pay out 10 times your wager. Would you make that bet? I'd reach for my wallet so fast my thumb would start a fire on my pocket.

Now imagine you could bet again, but only win if the wheel made a sequential 100 spins in your favor, otherwise you lose. Would you still play? Winning a single bet might be easy, but over many trials the odds are not in your favor.

People make these sorts of bets with data all of the time. A single server has a good chance of remaining available. When you run a cluster with thousands of servers, or billions of requests, the odds of any one breaking down becomes the rule.

A once-in-a-million disaster is commonplace in light of a billion opportunities.

## What is Riak

Riak is an open-source, distributed key/value database for high availability, fault-tolerance, and near-linear scalability. In short, Riak has remarkably high uptime and grows with you.

<!-- image: phone with 1/0's flying from it to a disk array -->

As the modern world stitches itself together with increasingly intricate connections, major shifts are occurring in information management. The web and networked devices spur an explosion of data collection and access unseen in the history of the world. The magnitude of values stored and managed continues to grow at a staggering rate, and in parallel, more people than ever require fast and reliable access to this data. This trend is known as *Big Data*.

<aside id="big-data" class="sidebar"><h3>So What is Big Data?</h3>

There's a lot of discussion around what constitutes <em>Big Data</em>.

I have a 6 Terabyte RAID in my house to store videos and other backups. Does that count? On the other hand, CERN grabbed about 200 Petabytes looking for the Higgs boson.

<!-- image: raid box -->

It's a hard number to pin down, because Big Data is a personal figure. What's big to one might be small to another. This is why many definitions don't refer to byte count at all, but instead about relative potentials. A reasonable, albeit wordy, definition of Big Data is provided by Gartner:

<blockquote><em>Big Data are high-volume, high-velocity, and/or high-variety information figures that require new forms of processing to enable enhanced decision making, insight discovery and process optimization.</em></blockquote></aside>

<h3>Always Bet on Riak</h3>

The sweet spot of Riak is high-volume (data that's available to read and write when you need it), high-velocity (easily responds to growth), and high-variety information figures (you can store any type of data as a value).

Riak was built as a solution to real Big Data problems, based on the *Amazon Dynamo* design. Dynamo is a highly available design---meaning that it responds to requests quickly at very large scales, even if your application is storing and serving terabytes of data a day. Riak had been used in production prior to being open-sourced in 2009. It's currently used by Github, Comcast, Voxer, Disqus and others, with the larger systems storing hundreds of TBs of data, and handling several GBs per node daily.

Riak was written in the Erlang programming language. Erlang was chosen due to its strong support for concurrency, solid distributed communication, hot code loading, and fault-tolerance. It runs on a virtual machine, so running Riak requires an Erlang installation.

So should you use Riak? A good rule of thumb for potential users is to ask yourself if every moment of downtime will cost you in some way (money, users, etc). Not all systems require such extreme amounts of uptime, and if you don't, Riak may not be for you.

## About This Book

This is not an "install and follow along" guide. This is a "read and comprehend" guide. Don't feel compelled to have Riak, or even have a computer handy, when starting this book. You may feel like installing at some point, and if so, instructions can be found in the [Riak docs](http://docs.basho.com).

In my opinion, the most important section of this book is the [concepts chapter](#concepts). If you already have a little knowledge it may start slow, but it picks up in a hurry. After laying the theoretical groundwork, we'll move onto helping [developers](#developers) use Riak, by learning how to query it and tinker with some settings. Finally, we'll go over the basic details that [operators](#operators) should know, such as how to set up a Riak cluster, configure some values, use optional tools, and more.

## Changes From 1.x

Riak 2.0 represents a major shift in the capabilities and focus of Riak as a data store. Riak has always been primarily focused on operational simplicity, and that has not changed. But when it came to design decisions, operations were always given priority over the needs of developers. This is changing. With the launch of 2.0, we've added some features that developers have wanted to see for quite a while. Namely, the following:

* __Strong Consistency__. Riak is still Eventually Consistent, too, but now you have a choice. Riak is now the easiest to manage database for adjusting the spectrum smoothly between AP and CP... per bucket, no less.
* __Better Search__. The makers of Riak have improved search by leveraging the power of the Solr search engine. You now get all of the queryability of distributed Solr, without the hassle of manual indexing.
* __Datatypes__. Riak historically has provided storage flexibility by allowing the storage of any binary object. This is still the case, but you now have the option of storing distributed maps, sets, counters, and flags that automatically converge in the face of conflicts.
* __Security__. A long-standing request that's day has finally come. Native Group/User access controls.
* __Bucket types__. Now you can support unlimited custom bucket properties, without the overhead of the old gossip protocol.
* __Ring Resizing__. Finally! Where in the past you were limited to a fixed ring size, you now have the option to dynamically increase/decrease the number of vnodes in your cluster.
* __Other improvements__. We've also made many other improvements, like simplified configuration management (no more messing with `app.config` and `vm.args`), reduced sibling explosions (via a new logical clock called DVV), improved internal metadata sharing (reducing gossip chatter), better AAE, and more.

This book also includes a new chapter written by John Daily, to help guide developers to write productive applications with Riak. We hope you enjoy the new, improved, *Not Quite So Little Riak Book*.