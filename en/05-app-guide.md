# Writing Applications

In the summer of 2012, I discovered
[Sijin Joseph's *Programmer Competency Matrix*](http://sijinjoseph.com/programmer-competency-matrix/)
and it spurred me to finally learn a functional programming language.

I grabbed a copy of
[Bruce Tate's *Seven Languages in Seven Weeks*](http://pragprog.com/book/btlang/seven-languages-in-seven-weeks). With my background in server and network administration, and a bit of server-side software
development experience, Erlang grabbed me and has yet to let go.

Learning Erlang led me to discover Basho and NoSQL technologies, and
ultimately to a job as technical evangelist for Basho, where I helped
edit
[Eric Redmond's *A Little Riak Book*](http://littleriakbook.com/). Helping
write Riak's documentation and interacting with developers has led me
to two conclusions:

* It's really *not* necessary to be a distributed systems expert to
  write applications for Riak.
* It nonetheless *is* necessary to think differently when designing
  Riak applications, and we at Basho haven't (yet) done a great job of
  making that fact obvious or surmountable.

Hence this guide.

Thanks to Mark Phillips for hiring me at Basho, Eric Redmond for
inspiring me to write this guide, and the entire Basho crew for
demanding and demonstrating excellence.

## Introduction

Riak is not a relational database. It is not a document store. It has
characteristics in common with other databases, but it is very much
its own beast, and writing
performant^[Yes, I'll argue *performant* is a proper word, thankyewverymuch],
scalable applications requires more than just a list of API functions:
it requires a different way of thinking about assembling and managing
data.

If you need to be convinced that Riak is the solution for you, this is
not the guide you're looking for. The Little Riak Book, Basho engineers, and satisfied
customers are better resources; my goal here is to help people avoid common
pitfalls that await the novice Riak developer. Designing applications
to work well with a distributed key/value store is not (yet) a common skill.

Because Riak is evolving rapidly to encompass new features and use cases, this
guide will steer clear of low-level details that can be found on
Basho's documentation website.

Furthermore, this neither an operations guide nor an architecture
guide. Understanding how Riak works under the covers is useful, but it
should not be necessary for software development.

### What do I need to read?

While I'd hope that everyone will read this whole document, I have
enough partially-read books on my shelves (analog and digital) to know
better.

Above all, read [How not to write a Riak application]. If the
anti-patterns make sense, feel free to skip [Denormalization] and jump
directly to [Data modeling].

If [Data modeling] and the preceding content makes sense, then the
guide has achieved its primary purpose of encouraging a different
mindset when thinking about how Riak applications should be designed.

Be sure to read [Write failures] (under [Request tuning]), because
Riak errors and write failures are two very different things.

The other particularly critical content is under
[Conflict resolution], because while it is possible to develop
applications that ignore the problem, such applications are probably
working correctly only when everything else in the environment is
working correctly.



## How not to write a Riak application

Writing a Riak application is very much **not** like writing an
application that relies on a relational database. The core ideas and
vocabulary from database theory still apply, of course, but many of
the decisions that inform the application layer are inverted.

Effectively all of these anti-patterns make some degree of sense when
writing an application against a SQL database. None of them lend
themselves to great Riak applications.

### Dynamic querying

Riak offers query features such as secondary indexes (**2i**),
MapReduce, and full-text search, but throwing a large quantity of data
into Riak and expecting those tools to find whatever you need is
setting yourself (and Riak) up to fail. Performance will be poor,
especially as you scale.

**Reads and writes in Riak should be as fast with ten billion values
in storage as with ten thousand.**

Key/value operations seem primitive (and they are) but you'll find
they are flexible, scalable, and very very fast (and predictably so).

Treat 2i and friends as tools to be applied judiciously, design the
main functionality of your application as if they don't exist, and
your software will continue to work at blazing speeds when you have
petabytes of data stored across dozens of servers.

### Normalization

Normalizating data is generally a useful approach in a relational
database, but unlikely to lead to happy results with Riak.

Riak lacks foreign keys constraints and join operations, two vital
parts of the normalization story, so reconstructing a single record
from multiple objects would involve multiple read requests; certainly
possible and fast enough on a small scale, but not ideal for larger
requests.

Instead, imagine the performance of your application if most of your
requests were a single, trivial read. Preparing and storing the
answers to queries you're going to ask later is a best practice for
Riak.

### Ducking conflict resolution

One of the first hurdles Basho faced when releasing Riak was educating
developers on the complexities of eventual consistency and the need to
intelligently resolve data conflicts.

Because Riak is optimized for high availability, *even when servers
are offline or disconnected from the cluster due to network failures*,
it is not uncommon for two servers to have different versions of a
piece of data.

The simplest approach to coping with this is to allow Riak to choose a
winner based on timestamps. It can do this more effectively if
developers follow Basho's guidance on sending updates with *vector
clock* metadata to help track causal history, but often concurrent
updates cannot be automatically resolved via vector clocks, and
trusting server clocks to determine which write was the last to arrive
is a **terrible** conflict resolution method.

Even if your server clocks are magically always in sync, are your
business needs well-served by blindly applying the most recent update?
Some databases have no alternative but to handle it that way, but we think
you deserve better.

Riak 2.0, when installed on new clusters, will default to retaining
conflicts and requiring the application to resolve them, but we're
also providing replicated data types to automate conflict resolution
on the servers.

If you want to minimize the need for conflict resolution, modeling
with as much immutable data as possible is a big win.

[Conflict resolution] covers this in much more detail.

### Mutability

For years, functional programmers have been singing the praises of
immutable data, and it confers significant advantages when using a
distributed data store like Riak.

Most obviously, conflict resolution is dramatically simplified when
objects are never updated.

Even in the world of single-server database servers, updating records
in place carries costs. Most databases lose all sense of history when
data is updated, and it's entirely possible for two different clients
to overwrite the same field in rapid succession leading to unexpected
results.

Some data is always going to be mutable, but thinking about the
alternative can lead to better design.

### SELECT * FROM &lt;table&gt;

A perfectly natural response when first encountering a populated
database is to see what's in it. In a relational database, you can
easily retrieve a list of tables and start browsing their records.

As it turns out, this is a terrible idea in Riak.

Not only is Riak optimized for unstructured, opaque data, it is also
not designed to allow for trivial retrieval of lists of buckets (very
loosely analogous to tables) and keys.

Doing so can put a great deal of stress on a large cluster and can
significantly impact performance.

It's a rather unusual idea for someone coming from a relational
mindset, but being able to algorithmically determine the key that you
need for the data you want to retrieve is a major part of the Riak
application story.

### Large objects

Because Riak sends multiple copies of your data around the network for
every request, values that are too large can clog the pipes, so to
speak, causing significant latency problems.

Basho generally recommends 1-4MB objects as a soft cap; larger sizes
are possible with careful tuning, however.

We'll return to object size when discussing [Conflict resolution]; for
the moment, suffice it to say that if you're planning on storing
*mutable* objects in the upper ranges of our recommendations, you're
particularly at risk of latency problems.

For significantly larger objects,
[Riak CS](http://basho.com/riak-cloud-storage/) offers an Amazon
S3-compatible (and also OpenStack Swift-compatible) key/value object
store that uses Riak under the hood.

### Running a single server

This is more of an operations anti-pattern, but it is a common
misunderstanding of Riak's architecture.

It is quite common to install Riak in a development environment using
its `devrel` build target, which creates 5 full Riak stacks (including
Erlang virtual machines) to run on one server to simulate a cluster.

However, running Riak on a single server for benchmarking or
production use is counterproductive, regardless of whether you have 1
stack or 5 on the box.

It is possible to argue that Riak is more of a database coordination
platform than a database itself. It uses Bitcask or LevelDB to persist
data to disk, but more importantly, it commonly uses *at least* 64
such embedded databases in a cluster.

Needless to say, if you run 64 databases simultaneously on a single
filesystem you are risking significant I/O and CPU contention unless
the environment is carefully tuned (and has some pretty fast disks).

Perhaps more importantly, Riak's core design goal, its raison d'être,
is high availability via data redundancy and related
mechanisms. Writing three copies of all your data to a single
server is mostly pointless, both contributing to resource contention
and throwing away Riak's ability to survive server failure.

### Further reading

* [Why Riak](http://docs.basho.com/riak/latest/theory/why-riak/) (docs.basho.com)
* [Data Modeling](http://docs.basho.com/riak/latest/dev/data-modeling/) (docs.basho.com)
* [Clocks Are Bad, Or, Welcome to the Wonderful World of Distributed Systems](https://basho.com/clocks-are-bad-or-welcome-to-distributed-systems/) (Basho blog)


## Denormalization

Normal forms are the holy grail of schema design in the relational
world. Duplication is misery, we learn. Disk space is constrained, so
let foreign keys and join operations and views reassemble your data.

Conversely, when you step into a world *without* join operations,
**stop normalizing**. In fact, go the other direction, and duplicate
your data as much as you need to. Denormalize all the things!

I'm sure you immediately thought of a few objections to
denormalization; I'll do what I can to dispel your fears. Read on,
Macduff.

### Disk space

Let me get the easy concern out of the way: don't worry about disk
space. I'm not advocating complete disregard for it, but one of the
joys of operating a Riak database is that adding more computing
resources and disk space is not a complex, painful operation that
risks downtime for your application or, worst of all, manual sharding
of your data.

Need more disk space? Add another server. Install your OS, install
Riak, tell the cluster you want to join it, and then pull the
trigger. Doesn't get much easier than that.

### Performance over time

If you've ever created a *really* large table in a relational
database, you have probably discovered that your performance is
abysmal. Yes, indexes help with searching large tables, but
maintaining those indexes are **expensive** at large data sizes.

Riak includes a data organization structure vaguely similar to a
table, called a *bucket*, but buckets don't carry the indexing
overhead of a relational table. As you dump more and more data into a
bucket, write (and read) performance is constant.

### Performance per request

Yes, writing the same piece of data multiple times is slower than
writing it once, by definition.

However, for many Riak use cases, writes can be asynchronous. No one
is (or should be) sitting at a web browser waiting for a sequence of
write requests to succeed.

What users care about is **read** performance. How quickly can you
extract the data that you want?

Unless your application is receiving many hundreds or thousands of new
pieces of data per second to be stored, you should have plenty of time
to write those entries individually, even if you write them multiple
times to different keys to make future queries faster. If you really
*are* receiving so many objects for storage that you don't have time
to write them individually, you can buffer and write blocks of them in
chunks.

In fact, a common data pattern is to assemble multiple objects into
larger collections for later retrieval, regardless of the ingest rate.

### What about updates?

One key advantage to normalization is that you only have to update any
given piece of data once.

However, many use cases that require large quantities of storage deal
with mostly immutable data, such as log entries, sensor readings, and
media storage. You don't change your sensor data after it arrives, so
why do you care if each set of inputs appears in five different places
in your database?

Any information which must be updated frequently should be confined to
small objects that are limited in scope.

<!-- Would be nice to have an example here -->

We'll talk much more about data modeling to account for mutable and
immutable data.

### Further reading

* [NoSQL Data Modeling Techniques](http://highlyscalable.wordpress.com/2012/03/01/nosql-data-modeling-techniques/) (Highly Scalable Blog)


## Data modeling

It can be hard to think outside the table, but once you do, you may
find interesting patterns that to use in any database, even
relational.[^sql-databases]

[^sql-databases]: Feel free to use a relational database when you're
willing to sacrifice the scalability, performance, and availability of
Riak...but why would you?

If you thoroughly absorbed the earlier content, some of this may feel
redundant, but not all of us are able to grasp the implications of the
key/value model, and I suspect you'll find a few interesting ideas
here.

### Terminology

Bucket
:   Virtual namespaces for keys
Bucket types
:   Collections of buckets for customization or security
Denormalize
:   Introduce redundancy into a data set
Immutable data
:   Data which, once written, is never updated
Key
:   A string which uniquely (per bucket) identifies values in Riak
Object
:   Another term for **value**
Value
:   The data associated with a key


### Rules to live by

As with most such lists, these are guidelines rather than hard rules,
but take them seriously. We'll talk later about alternative
approaches.

(@keys) Know thy keys.

    The cardinal rule of any key/value data store: the fastest way to get
    data is to know the key you want.

    How do you pull that off? Well, that's the trick, isn't it?

    The best way to always know the key you want is to be able to
    programmatically reproduce it based on information you already
    have. Need to know the sales data for one of your client's
    magazines in December 2013? Store it in a **sales** bucket and
    name the key after the client, magazine, and month/year combo.

    Guess what? Retrieving it will be much faster than running a SQL
    `select` statement in a relational database.

    And if it turns out that the magazine didn't exist yet, and there
    are no sales figures for that month? No problem. A negative
    response, especially for immutable data, is among the fastest
    operations Riak offers.

    Because keys are only unique within a bucket, the same unique
    identifier can be used in different buckets to represent different
    information about the same entity (e.g., a customer address might
    be in an `address` bucket with the customer id as its key).

(@namespace) Know thy namespaces.

    **Bucket types** (introduced in Riak 2.0) offer a way to secure
    and configure buckets. Buckets offer namespaces and configurable
    request parameters for keys. Both are good ways to segregate keys
    for data modeling.

    However, keys themselves define their own namespaces. If you want
    a hierarchy for your keys that looks like `sales/customer/month`,
    you don't need nested buckets: you just need to name your keys
    appropriately, as discussed in (@keys). `sales` can be your
    bucket, while each key is prepended with customer name and month.

(@views) Write your own views.

    The other name for this rule? **Know your queries.**

    Dynamic queries in Riak are expensive. Writing is cheap. Disk space is
    cheap.

    As your data flows into the system, generate the views you're going to
    want later. That magazine sales example from (@keys)? The December
    sales numbers are almost certainly aggregates of smaller values, but
    if you know in advance that monthly sales numbers are going to be
    requested frequently, when the last data arrives for that month the
    application can assemble the full month's statistics for later
    retrieval.

    Yes, getting accurate business requirements is non-trivial, but many
    Riak applications are version 2 or 3 of a system, written once the
    business discovered that the scalability story for MySQL, or Postgres,
    or MongoDB, simply wasn't up to the job of handling their growth.

(@small) Take small bites.

    Remember your parents' advice over dinner? They were right.

    When creating objects *that will be updated later*, constrain
    their scope and keep the number of contained elements low to
    reduce the odds of multiple clients attempting to update the data
    concurrently.

(@indexes) Create your own indexes.

    Riak offers metadata-driven indexes for values, but these face
    scaling challenges: in order to identify all objects for a given
    index value, roughly a third of the cluster must be involved.

    For many use cases, creating your own indexes is straightforward
    and much faster/more scalable, since you'll be managing and
    retrieving a single object.

    See [Conflict resolution] for more discussion of this.

(@immutable) Embrace immutability.

    As we discussed in [Mutability], immutable data offers a way out
    of some of the challenges of running a high volume, high velocity
    data store.

    If possible, segregate mutable from non-mutable data, ideally
    using different buckets for [request tuning][Request tuning].

    [Datomic](http://www.datomic.com) is a unique data storage system
    that leverages immutability for all data, with Riak commonly used
    as a backend data store. It treats any data item in its system as
    a "fact," to be potentially superseded by later facts but never
    updated.

(@hybrid) Don't fear hybrid solutions.

    As much we would all love to have a database that is an excellent
    solution for any problem space, we're a long way from that goal.

    In the meantime, it's a perfectly reasonable (and very common)
    approach to mix and match databases for different needs. Riak is
    very fast and scalable for retrieving keys, but it's decidedly
    suboptimal at ad hoc queries. If you can't model your way out of
    that problem, don't be afraid to store your keys with searchable
    metadata in a relational or other database that makes querying
    simpler.

    Just make sure that you consider failure scenarios when doing so;
    it would be unfortunate to make Riak's effective availability a
    slave to another database's weakness.

### Further reading

* [Use Cases](http://docs.basho.com/riak/latest/dev/data-modeling/)



## Conflict resolution

Conflict resolution is an inherent part of nearly any Riak
application, whether or not the developer knows it.

### Causality

Causality in a distributed data store is wonderfully useful when it
can be determined. If I retrieve a value, update it, and send it back
with metadata indicating when I got the value, Riak can determine
whether the new write is directly descended from what it already has
on disk.

With strong consistency, this context is mandatory: if the update to
an existing object is not explicitly derived from the latest version
of that object, it will be rejected.

With eventual consistency, Riak will take a new write regardless of
its context (aka **vector clock**).

### Siblings

With eventual consistency, if the vector clock cannot determine a
causal relationship between two copies of an object, Riak will create
**siblings**. Effectively, such an object is no longer a simple opaque
data blob, but rather two (or more) distinct blobs (siblings) waiting
to be resolved.

### Conflict resolution strategies

There are basically 6 distinct approaches for dealing with conflicts
in Riak, and well-written applications will typically use a
combination of these strategies depending on the nature of the data.[^conflict-tuning]

[^conflict-tuning]: If each bucket has its own conflict resolution
strategy, requests against that bucket can be tuned appropriately. For
an example, see [Tuning for immutable data].

* Ignore the problem and let Riak pick a winner based on timestamp and
  context if concurrent writes are received (aka "last write wins").
* Immutability: never update values, and thus never risk conflicts.
* Instruct Riak to retain conflicting writes and resolve them with
  custom business logic in the application.
* Instruct Riak to retain conflicting writes and resolve them using
  client-side data types designed to resolve conflicts automatically.
* Instruct Riak to retain conflicting writes and resolve them using
  server-side data types designed to resolve conflicts automatically.

And, as of Riak 2.0, strong consistency can be used to avoid conflicts
(but as we'll discuss below there are significant downsides to doing
so).


#### Last write wins

Prior to Riak 2.0, the default behavior was for Riak to resolve
siblings by default (see [Tuning parameters] for the parameter
`allow_mult`). With Riak 2.0, the default behavior changes to
retaining siblings for the application to resolve, although this will
not impact legacy Riak applications running on upgraded clusters.

For some use cases, letting Riak pick a winner is perfectly fine, but
make sure you're monitoring your system clocks and are comfortable
losing occasional (or not so occasional) updates.

#### Data types

It has always been possible to define data types on the client side to
merge conflicts automatically.

With Riak 1.4, Basho started introducing distributed data types to
allow the cluster to resolve conflicting writes automatically. The
first such types was a simple counter, but Riak 2.0 includes sets and
maps.

These types are still bound by the same basic constraints as the rest
of Riak. For example, if the same set is updated on either side of a
network split, requests for the set will respond differently until the
split heals; also, these objects should not be allowed to grow to
multiple megabytes in size.

#### Strong consistency

As of Riak 2.0, it is possible to indicate that values should be
managed using a consensus protocol, so a quorum of the servers
responsible for that data must agree to a change before it is
committed.

This is a useful tool, but keep in mind the tradeoffs: writes will be
slower due to the coordination overhead, and Riak's ability to
continue to serve requests in the prence of network partitions and
server failures will be compromised.

For example, if a majority of the primary servers for the data are
unavailable, Riak will refuse to answer read requests, because the
surviving servers have no way of knowing whether the data they contain
is accurate.

Thus, use this only when necessary, such as when the consequences of
conflicting writes are painful to cope with. An example of the need
for this comes from Riak CS: because users are allowed to create new
accounts, and because there's no convenient way to resolve username
conflicts if two accounts are created at the same time with the same
name, it is important to coordinate such requests.

### Conditional requests

It is possible to use conditional requests with Riak, but these are
fragile due to the nature of its availability/eventual consistency
model.

**Need content here.**

### Locks and constraints

As we'll see in [Modeling transactions], even without strong consistency it is
possible to define ACID-like transactions in Riak at the application
level.

Two mechanisms which are **not** guaranteed to work without strong
consistency are locks and constraints on values.

For financial operations, it may be necessary (or at least desirable)
to prevent a balance from dropping below a certain value (e.g.,
zero). This cannot be done with eventual consistency, because even
with transactions it is always possible for a balance to be decreased
on both sides of a network partition.

Even with `PW=2` and conditional requests weird things can
happen. Remember that `PW` requests can error out even when data is
written durably.

### Conflicting resolution

Resolving conflicts when data is being rapidly updated can feel
Sysiphean.

It's always possible that two different clients will attempt to
resolve the same conflict at the same time, or that another client
will update a value between the time that one client retrieves
siblings and it attempts to resolve them. In either case you may have
new conflicts created by conducting conflict resolution.

Consider this yet another plug to consider immutability.

### Further reading

* [Clocks Are Bad, Or, Welcome to the Wonderful World of Distributed Systems](http://basho.com/clocks-are-bad-or-welcome-to-distributed-systems/) (Basho blog)
* [Index for Fun and for Profit](http://basho.com/index-for-fun-and-for-profit/) (Basho blog)
* [Indexing the Zombie Apocalypse With Riak](http://basho.com/indexing-the-zombie-apocalypse-with-riak/) (Basho blog)


## Modeling transactions

Riak is definitely not an ACID database. Nonetheless, it is possible
to define applications which enforce ACID semantics.

**Need content here.**

### Further reading

* [HAT, not CAP: Introducing Highly Available Transactions](http://www.bailis.org/blog/hat-not-cap-introducing-highly-available-transactions/) (Peter Bailis's blog)



## Request tuning

Riak is extensively (perhaps *too* extensively) configurable. Much of
that flexibility involves platform tuning accessible only via the host
operating system, but several core behavioral values can (and should)
be managed by applications.

With the notable exceptions of `n_val` (commonly referred to as `N`)
and `allow_mult`, the parameters described below can be overridden
with each request. All of them can be configured per-bucket type
(available with Riak 2.0) or per-bucket.

### Key concepts

Any default value listed below as **quorum** is equivalent to
`n_val/2+1`, or **2** whenever `n_val` has not been modified.

**Primary** servers are the cluster members that, in the absence of any
network or server failure, are supposed to "own" any given key/value
pair.

Riak's key/value engine does not itself write values to storage. That
job is left to the **backends** that Riak supports: Bitcask, LevelDB,
and Memory.

No matter what the parameters below are set to, requests will be
sent to `n_val` servers on behalf of the client, **except** for
strongly-consistent read requests with Riak 2.0, which can be safely
retrieved from the current leader for that key/value pair.

### Tuning parameters

#### Leave this alone

`n_val`
:   The number of copies of data that are written. This is independent of the number of servers in the cluster. Default: **3**.

The `n_val` is vital to nearly everything that Riak does. The default
value of 3 should never be lowered except in special circumstances,
and changing it after a bucket has data can lead to unexpected
behavior.

#### Configure at the bucket

`allow_mult`
:    Specify whether this bucket retains conflicts for the application to resolve (`true`) or pick a winner using vector clocks and server timestamp even if the causality history does not indicate that it is safe to do so (`false`). See [Conflict resolution] for more. Default: **`false`** prior to Riak 2.0, **`true`** after

    You **should** give this value careful thought. You **must** know what it will be in your environment to do proper key/value data modeling.

`last_write_wins`
:    Setting this to `true` is a slightly stronger version of `allow_mult=false`: when possible, Riak will write new values to storage without bothering to compare against existing values. Default: **`false`**

#### Configure at the bucket or per-request
`r`
:   The number of servers that must *successfully* respond to a read request before the client will be sent a response. Default: **`quorum`**

`w`
:   The number of servers that must *successfully* respond to a write request before the client will be sent a response. Default: **`quorum`**

`pr`
:    The number of *primary* servers that must successfully respond to a read request before the client will be sent a response. Default: **0**

`pw`
:    The number of *primary* servers that must successfully respond to a write request before the client will be sent a response. Default: **0**

`dw`
:    The number of servers that must respond indicating that the value has been successfully handed off to the *backend* for durable storage before the client will be sent a response. Default: **2** (effective minimum **1**)

`notfound_ok`
:    Specifies whether the absence of a value on a server should be treated as a successful assertion that the value doesn't exist (`true`) or as an error that should not count toward the `r` or `pr` counts (`false`). Default: **`true`**


#### Impact

Generally speaking, the higher the integer values listed above, the
more latency will be involved, as the server that received the request
will wait for more servers to respond before replying to the client.

Higher values can also increase the odds of a timeout failure or, in
the case of the primary requests, the odds that insufficient primary
servers will be available to respond.

### Write failures

***Please read this. Very important. Really.***

The semantics for write failure are *very different* under eventually
consistent Riak than they are with the optional strongly consistent
writes available in Riak 2.0, so I'll tackle each separately.

#### Eventual consistency

In most cases when the client receives an error message on a write
request, *the write was not a complete failure*. Riak is designed to
preserve your writes whenever possible, even if the parameters for a
request are not met. **Riak will not roll back writes.**

Even if you attempt to read the value you just tried to write and
don't find it, that is **not** definitive proof that the write was a
complete failure. (Sorry.)

If the write is present on at least one server, *and* that server
doesn't crash and burn, *and* future updates don't supersede it,
the key and value written should make their way to all servers
responsible for them.

Retrying any updates that resulted in an error, with the appropriate
vector clock to help Riak intelligently resolve conflicts, won't cause
problems.

#### Strong consistency

Strong consistency is the polar opposite from the default Riak
behaviors. If a client receives an error when attempting to write a
value, it is a safe bet that the value is not stashed somewhere in the
cluster waiting to be propagated, **unless** the error is a timeout,
the least useful of all possible responses.

No matter what response you receive, if you read the key and get the
new value back[^client-libs], you can be confident that all future
successful reads (until the next write) will return that same value.

[^client-libs]: To be *absolutely certain* your value is in Riak, make
certain to issue a new read request; your client library could always
be caching the value you just wrote.

### Tuning for immutable data

If you constrain a bucket to contain nothing but immutable data, you
can tune for very fast responses to read requests by setting `r=1` and
`notfound_ok=false`.

This means that read requests will (as always) be sent to all `n_val`
servers, but the first server that responds with **a value other than
`notfound`** will be considered "good enough" for a response to the
client.

Ordinarily with `r=1` and the default value `notfound_ok=true` if the
first server that responds doesn't have a copy of your data you'll get
a `not found` response; if a failover server happens to be actively
serving requests, there's a very good chance it'll be the first to
respond since it won't yet have a copy of that key.

### Further reading

* [Buckets](http://docs.basho.com/riak/latest/theory/concepts/Buckets/) (docs.basho.com)
* [Eventual Consistency](http://docs.basho.com/riak/latest/theory/concepts/Eventual-Consistency/) (docs.basho.com)
* [Replication](http://docs.basho.com/riak/latest/theory/concepts/Replication/) (docs.basho.com)
* [Understanding Riak's Configurable Behaviors](http://basho.com/understanding-riaks-configurable-behaviors-part-1/) (Basho blog series)



## Locks, a cautionary tale

While assembling this guide, I tried to develop a data model that
would allow for reliable locking without strong consistency. That
attempt failed, but rather than throw the idea away entirely, I
decided to include it here to illustrate the complexities of coping
with eventual consistency.

Basic premise: multiple workers may be assigned data sets to process,
but each data set should be assigned to no more than one worker.

In the absence of strong consistency, the best an application can do
is use the `pr` and `pw` parameters (primary read, primary write) with
a value of `quorum` or `n_val`.

So, common features to all of these models:

* Lock for any given data set is a known key
* Value is a unique identifier for the worker

### Lock, a first draft

#### Sequence

Bucket: `allow_mult=false`

1. Worker reads with `pr=quorum` to determine whether a lock exists
2. If it does, move on to another data set
3. If it doesn't, create a lock with `pw=quorum`
4. Process data set to completion
5. Remove the lock

#### Failure scenario

1. Worker #1 reads the non-existent lock
2. Worker #2 reads the non-existent lock
3. Worker #2 writes its ID to the lock
4. Worker #2 starts processing the data set
4. Worker #1 writes its ID to the lock
5. Worker #1 starts processing the data set

### Lock, a second draft

Bucket: `allow_mult=false`

#### Sequence

1. Worker reads with `pr=quorum` to determine whether a lock exists
2. If it does, move on to another data set
3. If it doesn't, create a lock with `pw=quorum`
4. Read lock again with `pr=quorum`
5. If the lock exists with another worker's ID, move on to another
   data set
6. Process data set to completion
7. Remove the lock

#### Failure scenario

1. Worker #1 reads the non-existent lock
2. Worker #2 reads the non-existent lock
3. Worker #2 writes its ID to the lock
4. Worker #2 reads the lock and sees its ID
5. Worker #1 writes its ID to the lock
6. Worker #1 reads the lock and sees its ID
7. Both workers process the data set


If you've done any programming with threads before, you'll recognize
this as a common problem with non-atomic lock operations.

### Lock, a third draft

Bucket: `allow_mult=true`

#### Sequence

1. Worker reads with `pr=quorum` to determine whether a lock exists
2. If it does, move on to another data set
3. If it doesn't, create a lock with `pw=quorum`
4. Read lock again with `pr=quorum`
5. If the lock exists with another worker's ID **or** the lock
contains siblings, move on to another data set
6. Process data set to completion
7. Remove the lock

#### Failure scenario

1. Worker #1 reads the non-existent lock
2. Worker #2 reads the non-existent lock
3. Worker #2 writes its ID to the lock
5. Worker #1 writes its ID to the lock
6. Worker #1 reads the lock and sees a conflict
7. Worker #2 reads the lock and sees a conflict
8. Both workers move on to another data set

### Lock, a fourth draft

Bucket: `allow_mult=true`

#### Sequence

1. Worker reads with `pr=quorum` to determine whether a lock exists
2. If it does, move on to another data set
3. If it doesn't, create a lock with `pw=quorum` and a timestamp
4. Read lock again with `pr=quorum`
5. If the lock exists with another worker's ID **or** the lock
contains siblings **and** its timestamp is not the earliest, move on
to another data set
6. Process data set to completion
7. Remove the lock


#### Failure scenario

1. Worker #1 reads the non-existent lock
2. Worker #2 reads the non-existent lock
3. Worker #2 writes its ID and timestamp to the lock
4. Worker #2 reads the lock and sees its ID
5. Worker #2 starts processing the data set
6. Worker #1 writes its ID and timestamp to the lock
7. Worker #1 reads the lock and sees its ID with the lowest timestamp
8. Worker #1 starts processing the data set

At this point I may hear you grumbling: clearly worker #2 would have
the lower timestamp because it attempted its write first, and thus #1
would skip the data set and try another one.

Even *if* both workers are running on the same server (and thus
*probably* have timestamps that can be compared)[^clock-comparisons],
perhaps worker #1 started its write earlier but contacted an overloaded cluster
member that took longer to process the request.

[^clock-comparisons]: An important part of any distributed systems
discussion is the fact that clocks are inherently untrustworthy, and
thus calling any event the "last" to occur is an exercise in faith:
faith that a system clock wasn't set backwards in time by `ntpd` or an
impatient system administrator, faith that all clocks involved are in
perfect sync.

    And, to be clear, perfect synchronization of clocks across
    multiple systems is unattainable. Google is attempting to solve
    this by purchasing lots of atomic and GPS clocks at great expense,
    and even that only narrows the margin of error.


The same failure could occur if, instead of using timestamps for
comparison purposes, the ID of each worker was used for comparison
purposes. All it takes is for one worker to read its own write before
another worker's write request arrives.

### Conclusion

We can certainly come up with algorithms that limit the number of
times that multiple workers tackle the same job, but I have yet to
find one that guarantees exclusion.

What I found surprising about this exercise is that none of the
failure scenarios required some of the odder edge conditions that can
cause unexpected outcomes. For example, `pw=quorum` writes will return
an error to the client if 2 of the primary servers are not available,
but the value will *still* be written to the 3rd server and 2 fallback
servers. Predicting what will happens the next time someone tries to
read the key is challenging.

None of these algorithms required deletion of a value, but that is
particularly fraught with peril. It's not difficult to construct
scenarios where deleted values reappear if servers are temporarily
unavailable during the deletion request.


## Backends

As a developer of a Riak application, you may or may not have control
over the backend that stores the data for your application. You
should, however, be aware of the tradeoffs.

### Bitcask

Bitcask has two particularly compelling qualities: very low (and
predictable) latency, and configurable expiry of keys (TTL). The
latter is particularly handy because deleting data from Riak is a
delicate and often slow operation.

Bitcask is very fast because each object retrieval is at most two lookups:
find the key in memory, and seek directly to the point on disk where
the latest copy of its object lives.

#### Downsides

* Bitcask currently lacks a key feature that most developers think they
  want: secondary indexing (2i). Consider using term-based indexes
  instead.
* All keys stored on the server must be able to fit into RAM.
* TTL values are set per-backend instead of per-bucket, so if you need
  different expiration values, you will be forced to use the multi
  backend (below) to configure multiple Bitcask backends.
* Bitcask compaction operations can be expensive; Basho recommends
  tuning the compaction criteria and interval to prevent unacceptable
  latency spikes.

### LevelDB

Unlike Bitcask, which is home-grown by Basho, LevelDB originates with
Google, although it has been (and continues to be) *heavily*
customized to work well with Riak.

LevelDB offers 2i and does not require that all keys fit into memory.

#### Downsides

* LevelDB's latency profile is less predictable than Bitcasks's
  because it can take several disk seeks to retrieve an object.
* It does not (today) offer TTL.

### Memory

Riak can store all keys and values in RAM using the Memory backend,
which offers 2i and TTL.

#### Downsides
* Data is not persisted to disk.

  Because your data lives on multiple servers, it still offers
  reasonably robust storage, but a power failure or rolling system
  reboots can wipe out all of your data.

### Multi

It is possible for Riak to use a combination of the backends using a
multi-backend configuration.

#### Downsides

* Complex configuration[^cuttlefish].
* More contention for memory and other resources.
* Buckets must be created against the proper backend before data
  arrives unless the default backend is appropriate.

[^cuttlefish]: Riak 2.0 includes a new configuration mechanism
intended to reduce complexity and eliminate some common operational
errors, but backend configuration is still handled at each server in a
cluster and must be managed carefully.

### Important backend operational notes

Technically these are out of scope for an application development
guide, but given the potential for bad things to happen™, it seems
useful to point these out here.

* As hinted under [Multi], if a bucket contains data, changing
  backends for that bucket does not migrate the data. Instead the old
  data becomes invisible to Riak.
* If the backend for a bucket is configured inconsistently across the
  cluster (e.g., Bitcask on some servers but LevelDB on others) then
  features such as 2i or TTL will only work on portions of your data set.


## Dynamic querying

**Need lots of content here.**

### Secondary indexes (2i)

### Key & bucket lists

#### Key ranges

http://docs.basho.com/riak/latest/dev/using/keyfilters/

### MapReduce

* Perils of JS (prefer Erlang)
* Difficult to find debug information

### Full-text search

<!-- Yes, the Riak Search link below is intended to link to a specific
version of the docs rather than "latest" since the content will
presumably change significantly once 2.0 is released. -->

Riak's full-text search engine exists in two very different forms with
similar interfaces: the original
[Riak Search](http://docs.basho.com/riak/2.0.0/dev/advanced/search/),
written in-house by Basho and designed to look like
[Solr](http://lucene.apache.org/solr/), and the
[Yokozuna](https://github.com/basho/yokozuna) project for Riak 2.0,
which **is** Solr, with Riak handling the responsibility of feeding
Solr new content for indexing as values are written, updated, and
deleted.

#### Architectural differences

Basho's original Riak Search is term-based: searching for a specific
keyword would involve querying only those servers responsible for that
word. Searching for that same keyword using Yokozuna will involve a
"coverage query" of a representative subset of the cluster (like 2i),
which should be somewhat slower for a single term search, but for more
complex searches or large result sets that advantage will likely be
lost.


### Commit hooks

* Difficult to find debug information

### Custom hash functions

*more*
